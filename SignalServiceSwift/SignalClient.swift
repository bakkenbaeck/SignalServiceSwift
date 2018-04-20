//
//  SignalClient.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 06.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation
import Starscream

public class SignalClient {
    var socket: WebSocket?
    var sender: SignalSender?

    public var libraryStore: SignalLibraryStoreProtocol
    public var libraryStoreBridge: SignalLibraryStoreBridge
    public var signalContext: SignalContext
    public var signalKeyHelper: SignalKeyHelper

    public var store: SignalServiceStore

    public var shouldKeepSocketAlive: Bool = false

    lazy var keepAliveTimer: Timer = {
        Timer(fire: Date(), interval: 30.0, repeats: true, block: { t in
            if self.shouldKeepSocketAlive && self.socket?.isConnected != true {
                self.socket?.connect()
            } else {
                self.socket?.write(ping: Data())
            }
        })
    }()

    var networkClient: NetworkClient?

    public var baseURL: URL

    public init(baseURL: URL, persistenceStore: PersistenceStore) {
        self.baseURL = baseURL

        self.libraryStore = SignalLibraryStore()
        self.libraryStoreBridge = SignalLibraryStoreBridge(signalStore: self.libraryStore)
        self.signalContext = SignalContext(store: self.libraryStoreBridge)
        self.signalKeyHelper = SignalKeyHelper(context: self.signalContext)

        self.libraryStoreBridge.setup(with: self.signalContext.context)

        self.store = SignalServiceStore(persistenceStore: persistenceStore)

    }

    public func setupSender(username: String, password: String, deviceId: Int32, registrationId: UInt32, signalingKey: String) {
        let sender = SignalSender(username: username, password: password, deviceId: deviceId, remoteRegistrationId: registrationId, signalingKey: signalingKey)

        self.sender = sender

        let socketURL = URL(string: "wsss://\(self.baseURL.host!)/v1/websocket/?login=\(username)&password=\(password)")!

        self.socket = WebSocket(url: socketURL)
        self.socket?.delegate = self
        self.socket?.pongDelegate = self

        self.socket?.connect()

        RunLoop.main.add(self.keepAliveTimer, forMode: .defaultRunLoopMode)

        self.networkClient = NetworkClient(baseURL: self.baseURL, username: sender.username, password: sender.password)
    }

    public func sendMessage(_ body: String, to: SignalAddress) {
         guard let sender = self.sender else { return }

        self.networkClient?.fetchPreKeyBundle(for: to.name) { preKeyBundle in
            NSLog("Fetched pre key bundle")

            let sessionBuilder = SignalSessionBuilder(address: to, context: self.signalContext)!
            guard sessionBuilder.processPreKeyBundle(preKeyBundle) else {
                NSLog("Could not process prekey bundle!")
                fatalError()
            }

            NSLog("Processed pre key bundle")

            let sessionCipher = SignalSessionCipher(address: to, context: self.signalContext)

            let ciphertext = try! sessionCipher.encrypt(message: body)!

            let recipient = self.store.fetchOrCreateRecipient(name: to.name, deviceId: to.deviceId, remoteRegistrationId: preKeyBundle.registrationId)
            let chat = self.store.fetchOrCreateChat(with: recipient.name, in: self.store)

            let outgoingMessage = OutgoingSignalMessage(recipientId: recipient.name, chatId: chat.uniqueId, body: body, ciphertext: ciphertext)

            NSLog("Sending…")
            self.networkClient?.sendMessage(outgoingMessage, from: sender, to: recipient, in: chat) { success in
                if success {
                    self.store.save(outgoingMessage)
                }
            }
        }
    }

    func cipherMessage(from data: Data, ciphertextType: CiphertextType = .unknown) throws -> SignalLibraryMessage?  {
        var message: SignalLibraryCiphertextMessage? = nil
        var preKeyMessage: SignalLibraryPreKeyMessage? = nil

        if ciphertextType == .preKeyMessage {
            preKeyMessage = SignalLibraryPreKeyMessage(data: data, context: self.signalContext)
            if preKeyMessage == nil {
                return nil
            }
        } else if ciphertextType == .message {
            message = SignalLibraryCiphertextMessage(data: data, context: self.signalContext)
            if message == nil {
                return nil
            }
        } else {
            // Fall back to brute force type detection...
            preKeyMessage = SignalLibraryPreKeyMessage(data: data, context: self.signalContext)
            message = SignalLibraryCiphertextMessage(data: data, context: self.signalContext)
            if preKeyMessage == nil && message == nil {
                throw ErrorFromSignalError(.invalidArgument)
            }
        }

        return preKeyMessage ?? message
    }

    func decryptCiphertextEnvelope(_ envelope: Signalservice_Envelope) {
        guard let sender = self.sender else { return }

        let content = envelope.hasContent ? envelope.content : envelope.legacyMessage
        let senderAddress = SignalAddress(name: envelope.source, deviceId: Int32(envelope.sourceDevice))
        let sessionCipher = SignalSessionCipher(address: senderAddress, context: self.signalContext)

        guard let cipherMessage = try? self.cipherMessage(from: content),
            let concreteCipherMessage = cipherMessage else {
                NSLog("Could not decrypt message! (0)")
                return
        }

        if cipherMessage is SignalLibraryPreKeyMessage {
            self.networkClient?.checkPreKeys(in: self.signalContext, signalKeyHelper: self.signalKeyHelper, sender: sender)
        }

        let chat = self.store.fetchOrCreateChat(with: senderAddress.name, in: self.store)

        guard let _decryptedData = try? sessionCipher.decrypt(cipher: concreteCipherMessage),
            let decryptedData = _decryptedData,
            let incomingMessage = IncomingSignalMessage(signalContentData: decryptedData, chatId: chat.uniqueId) else {
                NSLog("Could not decrypt message! (1)")
                return
        }

        self.store.save(incomingMessage)
    }

    func processSocketMessage(_ message: Signalservice_WebSocketMessage) {
        guard let sender = self.sender else { return }

        if message.request.path == "/api/v1/message", message.request.verb == "PUT" {
            let payload = Cryptography.decryptAppleMessagePayload(message.request.body, withSignalingKey: sender.signalingKey)
            guard let envelope = try? Signalservice_Envelope(serializedData: payload) else {
                NSLog("No envelope!")
                return
            }

            switch envelope.type {
            case .ciphertext, .prekeyBundle:
                self.decryptCiphertextEnvelope(envelope)
            case .receipt, .keyExchange, .unknown:
                print(envelope.type)
            }


        } else {
            NSLog("Unsupported socket request: \(message.request)")
        }
    }

}

extension SignalClient: WebSocketDelegate {
    public func websocketDidConnect(socket: WebSocketClient) {
        NSLog("did connect")
    }

    public func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        NSLog("did disconnect: \((error as? WSError)?.message ?? "No error")")

        if self.shouldKeepSocketAlive {
            NSLog("reconnecting…")
            self.socket?.connect()
        }
    }

    public func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        NSLog("received: \(text)")
    }

    public func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        guard let webSocketMessage = try? Signalservice_WebSocketMessage(serializedData: data) else { return }

        switch webSocketMessage.type {
        case .request:
            self.processSocketMessage(webSocketMessage)
        default:
            fatalError("Should not receive socket response messages")
        }
    }
}

extension SignalClient: WebSocketPongDelegate {
    public func websocketDidReceivePong(socket: WebSocketClient, data: Data?) {
        NSLog("pong!")
    }
}
