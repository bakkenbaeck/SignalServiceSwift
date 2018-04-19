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

public enum SignalServiceStoreChangeType {
    case insert
    case update
    case delete
}

public protocol SignalServiceStoreChatDelegate {
    func signalServiceStoreWillChangeChats()
    func signalServiceStoreDidChangeChat(_ chat: SignalChat, at indexPath: IndexPath, for changeType: SignalServiceStoreChangeType)
    func signalServiceStoreDidChangeChats()
}

public protocol SignalServiceStoreMessageDelegate {
    func signalServiceStoreWillChangeMessages()
    func signalServiceStoreDidChangeMessage(_ message: SignalMessage, at indexPath: IndexPath, for changeType: SignalServiceStoreChangeType)
    func signalServiceStoreDidChangeMessages()
}

public class SignalServiceStore {
    public enum PersistedType: Int {
        case chat
        case message
    }

    public var numberOfChats: Int {
        return self.chats.count
    }

    public var chatDelegate: SignalServiceStoreChatDelegate?
    public var messageDelegate: SignalServiceStoreMessageDelegate?

    private var chats: [SignalChat] = []
    private var messages: [SignalMessage] = []

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

    func save(message: SignalMessage) {
        self.messageDelegate?.signalServiceStoreWillChangeMessages()

        let data = try! JSONEncoder().encode(message)
        self.persistenceStore.store(data, type: .message)

        self.messages.append(message)
        let indexPath = IndexPath(item: self.messages.index(of: message)!, section: 0)
        self.messageDelegate?.signalServiceStoreDidChangeMessage(message, at: indexPath, for: .insert)

        self.messageDelegate?.signalServiceStoreDidChangeMessages()
    }

    func save(chat: SignalChat) {
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
