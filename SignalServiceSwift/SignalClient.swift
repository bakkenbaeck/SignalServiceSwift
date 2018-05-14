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

    public init(baseURL: URL, contactsDelegate: SignalRecipientsDelegate, persistenceStore: PersistenceStore) {
        self.baseURL = baseURL

        self.libraryStore = SignalLibraryStore(delegate: persistenceStore)
        self.libraryStoreBridge = SignalLibraryStoreBridge(signalStore: self.libraryStore)
        self.signalContext = SignalContext(store: self.libraryStoreBridge)

        self.libraryStore.context = self.signalContext
        self.libraryStoreBridge.setup(with: self.signalContext.context)

        self.store = SignalServiceStore(persistenceStore: persistenceStore, contactsDelegate: contactsDelegate)
    }

    public func setupSender(username: String, password: String, deviceId: Int32, registrationId: UInt32? = nil, signalingKey: String) {
        // setup socket
        let socketURL = URL(string: "wsss://\(self.baseURL.host!)/v1/websocket/?login=\(username)&password=\(password)")!

        self.socket = WebSocket(url: socketURL)
        self.socket?.delegate = self
        self.socket?.pongDelegate = self

        self.socket?.connect()

        RunLoop.main.add(self.keepAliveTimer, forMode: .defaultRunLoopMode)

        let unwrappedRegistrationId = registrationId ?? self.libraryStore.localRegistrationId

        // setup message sender and network client
        let sender = SignalSender(username: username, password: password, deviceId: deviceId, remoteRegistrationId: unwrappedRegistrationId, signalingKey: signalingKey)
        let networkClient = NetworkClient(baseURL: self.baseURL, username: sender.username, password: sender.password)

        self.messageSender = SignalMessageManager(sender: sender, networkClient: networkClient, signalContext: self.signalContext, store: self.store, delegate: self)
    }

    public func sendGroupMessage(_ body: String, type: OutgoingSignalMessage.GroupMetaMessageType, to recipientAddresses: [SignalAddress], attachments: [Data] = []) {
        let names = recipientAddresses.map { (address) -> String in address.name }
        let chat = self.store.fetchOrCreateChat(with: names)
        guard let recipients = chat.recipients?.filter({ recipient -> Bool in recipient.name != self.messageSender?.sender.username }) else { return }

        let message = OutgoingSignalMessage(recipientId: chat.uniqueId, chatId: chat.uniqueId, body: body, groupMessageType: type, store: self.store)

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
