//
//  SignalClient.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 06.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Starscream

public struct DebugLevel {
    public enum DebugLevelType {
        case errorOnly
        case verbose
    }

    public static var current: DebugLevelType = .errorOnly
}

extension Array where Element: Equatable {
    mutating func delete(element elementToDelete: Element) {
        self = self.filter { element -> Bool in
            element != elementToDelete
        }
    }

    func deleting(element elementToDelete: Element) -> [Element] {
        return self.filter { element -> Bool in
            element != elementToDelete
        }
    }
}

public class SignalClient {
    var socket: WebSocket?

    var messageSender: SignalMessageManager?

    /// TODO: make this internal, move user bootstrapping data generation to client.
    public var libraryStore: SignalLibraryStoreProtocol
    var libraryStoreBridge: SignalLibraryStoreBridge
    public var signalContext: SignalContext

    public var store: SignalServiceStore

    public var shouldKeepSocketAlive: Bool = false

    lazy var keepAliveTimer: Timer = {
        Timer(fire: Date(), interval: 30.0, repeats: true) { _ in
            if self.shouldKeepSocketAlive && self.socket?.isConnected != true {
                self.socket?.connect()
            } else {
                self.socket?.write(ping: Data())
            }
        }
    }()

    public var baseURL: URL

    public init(baseURL: URL, recipientsDelegate: SignalRecipientsDisplayDelegate, persistenceStore: PersistenceStore) {
        self.baseURL = baseURL

        self.libraryStore = SignalLibraryStore(delegate: persistenceStore)
        self.libraryStoreBridge = SignalLibraryStoreBridge(signalStore: self.libraryStore)
        self.signalContext = SignalContext(store: self.libraryStoreBridge)

        self.libraryStore.context = self.signalContext
        self.libraryStoreBridge.setup(with: self.signalContext.context)

        self.store = SignalServiceStore(persistenceStore: persistenceStore, contactsDelegate: recipientsDelegate)
    }

    public func generateUserBootstrap(username: String, password: String) -> [String: Any] {
        let identityKeyPair = self.signalContext.signalKeyHelper.generateAndStoreIdentityKeyPair()!
        let signalingKey = Data.generateSecureRandomData(count: 52).base64EncodedString()
        let registrationId = signalContext.signalKeyHelper.generateRegistrationId()

        let identityPublicKey = identityKeyPair.publicKey.base64EncodedString()

        let signedPreKey = self.signalContext.signalKeyHelper.generateSignedPreKey(withIdentity: identityKeyPair, signedPreKeyId: 0)
        let preKeys = self.signalContext.signalKeyHelper.generatePreKeys(withStartingPreKeyId: 1, count: 100)

        for prekey in preKeys {
            _ = self.libraryStore.storePreKey(data: prekey.serializedData, id: prekey.preKeyId)
        }

        self.libraryStore.storeSignedPreKey(signedPreKey.serializedData, signedPreKeyId: signedPreKey.preKeyId)
        self.libraryStore.storeCurrentSignedPreKeyId(signedPreKey.preKeyId)
        self.libraryStore.localRegistrationId = registrationId

        let sender = SignalSender(username: username, password: password, deviceId: 1, remoteRegistrationId: registrationId, signalingKey: signalingKey)
        self.store.storeSender(sender)
        
        let networkClient = NetworkClient(baseURL: self.baseURL, username: sender.username, password: sender.password)
        self.messageSender = SignalMessageManager(sender: sender, networkClient: networkClient, signalContext: self.signalContext, store: self.store, delegate: self)

        var prekeysDict = [[String: Any]]()

        for prekey in preKeys {
            let prekeyParam: [String: Any] = [
                "keyId": prekey.preKeyId,
                "publicKey": prekey.keyPair.publicKey.base64EncodedString()
            ]
            prekeysDict.append(prekeyParam)
        }

        let signedPreKeyDict: [String: Any] = [
            "keyId": Int(signedPreKey.preKeyId),
            "publicKey": signedPreKey.keyPair.publicKey.base64EncodedString(),
            "signature": signedPreKey.signature.base64EncodedString()
        ]

        let payload: [String: Any] = [
            "identityKey": identityPublicKey,
            "password": password,
            "preKeys": prekeysDict,
            "registrationId": Int(registrationId),
            "signalingKey": signalingKey,
            "signedPreKey": signedPreKeyDict
        ]

        return payload
    }

    public func startSocket() {
        guard let sender = self.store.fetchSender() else { return }

        let socketURL = URL(string: "\(self.baseURL.absoluteString)/v1/websocket/?login=\(sender.username)&password=\(sender.password)")!

        self.socket = WebSocket(url: socketURL)
        self.socket?.delegate = self
        self.socket?.pongDelegate = self

        self.socket?.connect()

        let networkClient = NetworkClient(baseURL: self.baseURL, username: sender.username, password: sender.password)
        self.messageSender = SignalMessageManager(sender: sender, networkClient: networkClient, signalContext: self.signalContext, store: self.store, delegate: self)

        RunLoop.main.add(self.keepAliveTimer, forMode: .defaultRunLoopMode)
    }

    public func sendGroupMessage(_ body: String, type: OutgoingSignalMessage.GroupMetaMessageType, to recipientAddresses: [SignalAddress], attachments: [Data] = []) {
        let names = recipientAddresses.map { (address) -> String in address.name }
        let chat = self.store.fetchOrCreateChat(with: names)
        guard let recipients = chat.recipients?.filter({ recipient -> Bool in recipient.name != self.messageSender?.sender.username }) else { return }

        let message = OutgoingSignalMessage(recipientId: chat.uniqueId, chatId: chat.uniqueId, body: body, groupMessageType: type, store: self.store)
        try? self.store.save(message)

        let dispatchGroup = DispatchGroup()
        for attachment in attachments {
            dispatchGroup.enter()
            self.messageSender?.uploadAttachment(attachment, in: message) { _ in
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            for recipient in recipients {
                self.messageSender?.sendMessage(message, to: recipient, in: chat) { success in
                    if success && type == .deliver, recipient == recipients.first {
                        do {
                            try self.store.save(message)
                        } catch (let error) {
                            NSLog("Could not save message: %@", error.localizedDescription)
                        }
                    }
                }
            }
        }
    }

    public func sendMessage(_ body: String, to recipientAddress: SignalAddress, in chat: SignalChat, attachments: [Data] = []) {
        let message = OutgoingSignalMessage(recipientId: recipientAddress.name, chatId: chat.uniqueId, body: body, store: self.store)
        try? self.store.save(message)

        let dispatchGroup = DispatchGroup()
        for attachment in attachments {
            dispatchGroup.enter()
            self.messageSender?.uploadAttachment(attachment, in: message) { _ in
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            self.messageSender?.sendMessage(message, to: recipientAddress, in: chat) { success in
                if success {
                    do {
                        try self.store.save(message)
                    } catch (let error) {
                        NSLog("Could not save message: %@", error.localizedDescription)
                    }
                }
            }
        }
    }
}

extension SignalClient: SignalMessageManagerDelegate {
    func sendSocketMessageAcknowledgement(_ message: Signalservice_WebSocketMessage) {
        self.socket?.write(data: try! message.serializedData())
    }
}

extension SignalClient: WebSocketDelegate {
    public func websocketDidConnect(socket: WebSocketClient) {
        if DebugLevel.current == .verbose {
            NSLog("did connect")
        }
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
            self.messageSender?.processSocketMessage(webSocketMessage)
        default:
            fatalError("Should not receive socket response messages")
        }
    }
}

extension SignalClient: WebSocketPongDelegate {
    public func websocketDidReceivePong(socket: WebSocketClient, data: Data?) {
        if DebugLevel.current == .verbose {
            NSLog("pong!")
        }
    }
}
