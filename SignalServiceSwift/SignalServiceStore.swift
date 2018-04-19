//
//  SignalServiceStore.swift
//  SignalServiceSwift
//
//  Created by Igor Ranieri on 17.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation

public protocol PersistenceStore {
    func loadChats() -> [Data]
    func loadMessages() -> [Data]

    func store(_ data: Data, type: SignalServiceStore.PersistedType)
}

public protocol SignalServiceStoreChatDelegate {
    func signalServiceStoreWillChangeChats()
    func signalServiceStoreDidChangeChat(_ chat: SignalChat, at indexPath: IndexPath, for changeType: SignalServiceStore.ChangeType)
    func signalServiceStoreDidChangeChats()
}

public protocol SignalServiceStoreMessageDelegate {
    func signalServiceStoreWillChangeMessages()
    func signalServiceStoreDidChangeMessage(_ message: SignalMessage, at indexPath: IndexPath, for changeType: SignalServiceStore.ChangeType)
    func signalServiceStoreDidChangeMessages()
}

public class SignalServiceStore {
    public enum ChangeType {
        case insert
        case update
        case delete
    }

    public enum PersistedType: Int {
        case chat
        case message
        case recipient
    }

    public var numberOfChats: Int {
        return self.chats.count
    }

    public var chatDelegate: SignalServiceStoreChatDelegate?
    public var messageDelegate: SignalServiceStoreMessageDelegate?

    private var chats: [SignalChat] = []
    private var messages: [SignalMessage] = []
    private var recipients: [SignalRecipient] = []

    private var persistenceStore: PersistenceStore

    public init(persistenceStore: PersistenceStore) {
        self.persistenceStore = persistenceStore

        let chatsData = self.persistenceStore.loadChats()
        let messagesData = self.persistenceStore.loadMessages()

        for data in chatsData {
            let chat = try! JSONDecoder().decode(SignalChat.self, from: data)
            chat.store = self

            self.chats.append(chat)
        }

        for data in messagesData {
            let message = try! JSONDecoder().decode(SignalMessage.self, from: data)
            self.messages.append(message)
        }
    }

    public func chat(at index: Int) -> SignalChat? {
        return self.chats[index]
    }

    func fetchOrCreateRecipient(name: String, deviceId: Int32, remoteRegistrationId: UInt32) -> SignalRecipient {
        let recipient: SignalRecipient

        if let existingRecipient = self.recipients.first(where: { recipient -> Bool in
            return recipient.name == name && recipient.deviceId == deviceId && recipient.remoteRegistrationId == remoteRegistrationId
        }) {
            recipient = existingRecipient
        } else {
            recipient = SignalRecipient(name: name, deviceId: deviceId, remoteRegistrationId: remoteRegistrationId)

            self.save(recipient)
        }

        return recipient
    }

    func fetchOrCreateChat(with recipientIdentifier: String, in store: SignalServiceStore) -> SignalChat {
        if let chat = self.chat(recipientIdentifier: recipientIdentifier) {
            return chat
        } else  {
            let chat = SignalChat(recipientIdentifier: recipientIdentifier, in: store)
            self.save(chat)

            return chat
        }
    }

    func chat(recipientIdentifier: String) -> SignalChat? {
        return self.chats.first(where: { chat -> Bool in
            chat.recipientIdentifier == recipientIdentifier
        })
    }

    func chat(chatId: String) -> SignalChat? {
        return self.chats.first(where: { chat -> Bool in
            chat.uniqueId == chatId
        })
    }

    func messages(for chat: SignalChat) -> [SignalMessage] {
        let messages = self.messages.compactMap({ message -> SignalMessage? in
            message.chatId == chat.uniqueId ? message : nil
        }).sorted { (a, b) -> Bool in
            a.timestamp < b.timestamp
        }

        return messages
    }

    func save(_ recipient: SignalRecipient) {
        let data = try! JSONEncoder().encode(recipient)
        self.persistenceStore.store(data, type: .recipient)
    }

    func save(_ message: SignalMessage) {
        self.messageDelegate?.signalServiceStoreWillChangeMessages()

        let data = try! JSONEncoder().encode(message)
        self.persistenceStore.store(data, type: .message)

        self.messages.append(message)
        let indexPath = IndexPath(item: self.messages.index(of: message)!, section: 0)
        self.messageDelegate?.signalServiceStoreDidChangeMessage(message, at: indexPath, for: .insert)

        self.messageDelegate?.signalServiceStoreDidChangeMessages()
    }

    func save(_ chat: SignalChat) {
        self.chatDelegate?.signalServiceStoreWillChangeChats()

        let data = try! JSONEncoder().encode(chat)
        self.persistenceStore.store(data, type: .chat)

        self.chats.append(chat)
        let indexPath = IndexPath(item: self.chats.index(of: chat)!, section: 0)
        self.chatDelegate?.signalServiceStoreDidChangeChat(chat, at: indexPath, for: .insert)

        self.chatDelegate?.signalServiceStoreDidChangeChats()
    }

    func deleteAllChatsAndMessages() {
        self.chats = []
        self.messages = []
    }
}
