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
    var socket: WebSocket
    let sender: SignalSender

    public var store: SignalServiceStore

    public var shouldKeepSocketAlive: Bool

    lazy var keepAliveTimer: Timer = {
        Timer(fire: Date(), interval: 30.0, repeats: true, block: { t in
            if self.shouldKeepSocketAlive && !self.socket.isConnected {
                self.socket.connect()
            } else {
                self.socket.write(ping: Data())
            }
        })
    }()

    let networkClient: NetworkClient

    public var baseURL: URL {
        return self.networkClient.baseURL
    }

    public init(baseURL: URL, signalingKey: String, username: String, password: String, deviceId: Int32, registrationId: UInt32, signalKeyHelper: SignalKeyHelper, signalContext: SignalContext, store: SignalServiceStore) {

        self.store = store

        self.shouldKeepSocketAlive = false
        self.networkClient = NetworkClient(baseURL: baseURL)

        self.sender = SignalSender(username: username, password: password, deviceId: deviceId, remoteRegistrationId: registrationId, signalingKey: signalingKey, signalKeyHelper: signalKeyHelper, signalContext: signalContext)

        let socketURL = URL(string: "wsss://chat.internal.service.toshi.org/v1/websocket/?login=\(username)&password=\(password)")!

        self.socket = WebSocket(url: socketURL)
        self.socket.delegate = self
        self.socket.pongDelegate = self

        self.socket.connect()

        NSLog("TEST")

        RunLoop.main.add(self.keepAliveTimer, forMode: .defaultRunLoopMode)
    }

    public func sendMessage(_ body: String, to: SignalAddress) {
        self.networkClient.fetchPreKeyBundle(for: to.name, with: self.sender) { preKeyBundle in
            NSLog("Fetched pre key bundle")

            let sessionBuilder = SignalSessionBuilder(address: to, context: self.sender.signalContext)!
            guard sessionBuilder.processPreKeyBundle(preKeyBundle) else {
                NSLog("Could not process prekey bundle!")
                fatalError()
            }

            NSLog("Processed pre key bundle")

            let sessionCipher = SignalSessionCipher(address: to, context: self.sender.signalContext)

            let ciphertext = try! sessionCipher.encrypt(message: body)!

            let recipient = SignalRecipient(name: to.name, deviceId: to.deviceId, remoteRegistrationId: preKeyBundle.registrationId)
            let chat = SignalChat.fetchOrCreateChat(with: to.name, in: self.store)
            let outgoingMessage = OutgoingSignalMessage(recipientId: recipient.name, chatId: chat.uniqueId, body: body, ciphertext: ciphertext)

            NSLog("Sending…")
            self.networkClient.sendMessage(outgoingMessage, from: self.sender, to: recipient, in: chat) { success in
                if success {
                    self.store.save(message: outgoingMessage)
                }
            }
        }
    }

    func cipherMessage(from data: Data, ciphertextType: CiphertextType = .unknown) throws -> SignalCipherMessageProtocol?  {
        var message: SignalCipherMessage? = nil
        var preKeyMessage: SignalPreKeyMessage? = nil

        if ciphertextType == .preKeyMessage {
            preKeyMessage = SignalPreKeyMessage(data: data, context: self.sender.signalContext)
            if preKeyMessage == nil {
                return nil
            }
        } else if ciphertextType == .message {
            message = SignalCipherMessage(data: data, context: self.sender.signalContext)
            if message == nil {
                return nil
            }
        } else {
            // Fall back to brute force type detection...
            preKeyMessage = SignalPreKeyMessage(data: data, context: self.sender.signalContext)
            message = SignalCipherMessage(data: data, context: self.sender.signalContext)
            if preKeyMessage == nil && message == nil {
                throw ErrorFromSignalError(.invalidArgument)
            }
        }

        return preKeyMessage ?? message
    }

    func decryptCiphertextEnvelope(_ envelope: Signalservice_Envelope) {
        let content = envelope.hasContent ? envelope.content : envelope.legacyMessage
        let senderAddress = SignalAddress(name: envelope.source, deviceId: Int32(envelope.sourceDevice))
        let sessionCipher = SignalSessionCipher(address: senderAddress, context: self.sender.signalContext)

        guard let cipherMessage = try? self.cipherMessage(from: content),
            let concreteCipherMessage = cipherMessage else {
                NSLog("Could not decrypt message! (0)")
                return
        }

        if cipherMessage is SignalPreKeyMessage {
            self.networkClient.checkPreKeys(for: self.sender)
        }

        let chat = SignalChat.fetchOrCreateChat(with: senderAddress.name, in: self.store)

        guard let _decryptedData = try? sessionCipher.decrypt(cipher: concreteCipherMessage as! SignalCiphertext),
            let decryptedData = _decryptedData,
            let incomingMessage = IncomingSignalMessage(from: decryptedData, chatId: chat.uniqueId) else {
                NSLog("Could not decrypt message! (1)")
                return
        }

        self.store.save(message: incomingMessage)
    }

    func processSocketMessage(_ message: Signalservice_WebSocketMessage) {
        if message.request.path == "/api/v1/message", message.request.verb == "PUT" {
            let payload = Cryptography.decryptAppleMessagePayload(message.request.body, withSignalingKey: self.sender.signalingKey)
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
        NSLog("did disconnect: \(error?.localizedDescription ?? "No error")")

        if self.shouldKeepSocketAlive {
            NSLog("reconnecting…")
            self.socket.connect()
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
