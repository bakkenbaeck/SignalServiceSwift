//
//  SignalServiceStore.swift
//  SignalServiceSwift
//
//  Created by Igor Ranieri on 17.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

public protocol PersistenceStore: SignalLibraryStoreDelegate {
    func retrieveAllObjects(ofType type: SignalServiceStore.PersistedType) -> [Data]

    func update(_ data: Data, key: String, type: SignalServiceStore.PersistedType)
    func store(_ data: Data, key: String, type: SignalServiceStore.PersistedType)
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

    public enum PersistedType: String {
        case chat
        case incomingMessage
        case outgoingMessage
        case recipient
        case infoMessage
        case attachmentPointer
    }

    public var numberOfChats: Int {
        return self.chats.count
    }

    public var chatDelegate: SignalServiceStoreChatDelegate?
    public var messageDelegate: SignalServiceStoreMessageDelegate?
    public var contactsDelegate: SignalRecipientsDelegate

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private var chats: [SignalChat] = []

    private var messages: [SignalMessage] = []

    private var recipients: [SignalAddress] = []

    private var attachmentPointers: [SignalServiceAttachmentPointer] = []

    private var persistenceStore: PersistenceStore?

    public init(persistenceStore: PersistenceStore? = nil, contactsDelegate: SignalRecipientsDelegate) {
        self.contactsDelegate = contactsDelegate
        self.persistenceStore = persistenceStore

        let chatsData = self.persistenceStore?.retrieveAllObjects(ofType: .chat) ?? []
        let incomingMessagesData = self.persistenceStore?.retrieveAllObjects(ofType: .incomingMessage) ?? []
        let outgoingMessagesData = self.persistenceStore?.retrieveAllObjects(ofType: .outgoingMessage) ?? []
        let infoMessagesData = self.persistenceStore?.retrieveAllObjects(ofType: .infoMessage) ?? []
        let recipientsData = self.persistenceStore?.retrieveAllObjects(ofType: .recipient) ?? []
        let attachmentsData = self.persistenceStore?.retrieveAllObjects(ofType: .attachmentPointer) ?? []

        var messages: [SignalMessage] = []

        do {
            // chats
            for data in chatsData {
                let chat = try self.decoder.decode(SignalChat.self, from: data)
                chat.store = self
                chat.contactsDelegate = self.contactsDelegate

                self.chats.append(chat)
            }

            // messages
            for data in incomingMessagesData {
                let message = try self.decoder.decode(IncomingSignalMessage.self, from: data)
                message.store = self
                messages.append(message)
            }
            for data in outgoingMessagesData {
                let message = try self.decoder.decode(OutgoingSignalMessage.self, from: data)
                message.store = self
                messages.append(message)
            }
            for data in infoMessagesData {
                let message = try self.decoder.decode(InfoSignalMessage.self, from: data)
//                 message.store = self
                messages.append(message)
            }

            messages.sort { (a, b) -> Bool in
                a.timestamp > b.timestamp
            }

            self.messages.append(contentsOf: messages)

            // recipients
            var recipients = [SignalAddress]()

            for data in recipientsData {
                let recipient = try self.decoder.decode(SignalAddress.self, from: data)
                recipients.append(recipient)
            }

            self.recipients.append(contentsOf: recipients)

            var attachments = [SignalServiceAttachmentPointer]()
            for data in attachmentsData {
                let attachment = try self.decoder.decode(SignalServiceAttachmentPointer.self, from: data)
                attachments.append(attachment)
            }

            self.attachmentPointers.append(contentsOf: attachments)

        } catch (let error) {
            NSLog("Could not decode chat or message: %@", error.localizedDescription)
        }
    }

    public func chat(at index: Int) -> SignalChat? {
        return self.chats[index]
    }

    func fetchOrCreateRecipient(name: String, deviceId: Int32) -> SignalAddress {
        let recipient: SignalAddress

        if let existingRecipient = self.recipients.first(where: { recipient -> Bool in
            recipient.name == name // && recipient.deviceId == deviceId // && recipient.remoteRegistrationId == remoteRegistrationId
        }) {
            recipient = existingRecipient
        } else {
            recipient = SignalAddress(name: name, deviceId: deviceId)
            self.recipients.append(recipient)

            do {
                try self.save(recipient)
            } catch (let error) {
                NSLog("Could not save recipient: %@", error.localizedDescription)
            }
        }

        return recipient
    }

    public func fetchOrCreateChat(with recipientIdentifier: String) -> SignalChat {
        if let chat = self.chat(recipientIdentifier: recipientIdentifier) {
            return chat
        } else {
            let chat = SignalChat(recipientIdentifier: recipientIdentifier, in: self)
            chat.contactsDelegate = self.contactsDelegate

            do {
                try self.save(chat)
            } catch (let error) {
                NSLog("Could not save chat: %@", error.localizedDescription)
            }

            return chat
        }
    }

    public func fetchOrCreateChat(with recipientIdentifiers: [String]) -> SignalChat {
        if let chat = self.groupChat(recipientIdentifiers: recipientIdentifiers) {
            return chat
        } else {
            let chat = SignalChat(recipientIdentifiers: recipientIdentifiers, in: self)
            chat.contactsDelegate = self.contactsDelegate

            do {
                try self.save(chat)
            } catch (let error) {
                NSLog("Could not save chat: %@", error.localizedDescription)
            }

            return chat
        }
    }

    func fetchOrCreateChat(groupId: String, members: [String]) -> SignalChat {
        if let chat = self.groupChat(groupId: groupId) {
            return chat
        } else {
            let chat = SignalChat(recipientIdentifiers: members, in: self)
            chat.uniqueId = groupId
            chat.contactsDelegate = self.contactsDelegate

            do {
                try self.save(chat)
            } catch (let error) {
                NSLog("Could not save chat: %@", error.localizedDescription)
            }

            return chat
        }
    }

    func recipients(with identifiers: [String]) -> [SignalAddress] {
        let recipients = identifiers.map { identifier -> SignalAddress in
            self.fetchOrCreateRecipient(name: identifier, deviceId: 1)
        }

        return recipients
    }

    func attachment(with id: String) -> SignalServiceAttachmentPointer? {
        return self.attachmentPointers.first { pointer -> Bool in
            pointer.uniqueId == id
        }
    }

    func chat(recipientIdentifier: String) -> SignalChat? {
        return self.chats.first { chat -> Bool in
            chat.recipientIdentifier == recipientIdentifier
        }
    }

    func groupChat(recipientIdentifiers: [String]) -> SignalChat? {
        return self.chats.first { chat -> Bool in
            chat.recipientIdentifiers == recipientIdentifiers
        }
    }

    func groupChat(groupId: String) -> SignalChat? {
        let chat = self.chats.first { chat -> Bool in
            chat.uniqueId == groupId
        }

        return chat
    }

    func chat(chatId: String) -> SignalChat? {
        return self.chats.first { chat -> Bool in
            chat.uniqueId == chatId
        }
    }

    func messages(for chat: SignalChat) -> [SignalMessage] {
        let messages = self.messages.compactMap({ message -> SignalMessage? in
            message.chatId == chat.uniqueId ? message : nil
        }).sorted { (a, b) -> Bool in
            a.timestamp < b.timestamp
        }

        return messages
    }

    func messages<T: SignalMessage>(timestamp: UInt64, type: PersistedType) -> [T] {
        let messages = self.messages.filter { message -> Bool in
            var isType = false
            switch type {
            case .outgoingMessage:
                isType = message is OutgoingSignalMessage
            case .incomingMessage:
                isType = message is IncomingSignalMessage
            case .infoMessage:
                isType = message is InfoSignalMessage
            default:
                break
            }

            return message.timestamp == timestamp && isType
        }

        return messages as? [T] ?? []
    }

    func save(_ recipient: SignalAddress) throws {
        let data = try self.encoder.encode(recipient)
        self.persistenceStore?.store(data, key: recipient.name, type: .recipient)
    }

    func save(_ message: SignalMessage) throws {
        DispatchQueue.main.async {
            self.messageDelegate?.signalServiceStoreWillChangeMessages()
        }

        if let message = message as? OutgoingSignalMessage {
            let data = try self.encoder.encode(message)
            self.persistenceStore?.store(data, key: message.uniqueId, type: .outgoingMessage)
        } else if let message = message as? IncomingSignalMessage {
            let data = try self.encoder.encode(message)
            self.persistenceStore?.store(data, key: message.uniqueId, type: .incomingMessage)
        } else if let message = message as? InfoSignalMessage {
            let data = try self.encoder.encode(message)
            self.persistenceStore?.store(data, key: message.uniqueId, type: .infoMessage)
        } else {
            fatalError("Unsupported message type: \(message)")
        }

        // update?
        if self.messages.contains(message) {
            if let chat = self.chat(chatId: message.chatId) {
                let indexPath = IndexPath(item: chat.visibleMessages.index(of: message)!, section: 0)
                DispatchQueue.main.async {
                    self.messageDelegate?.signalServiceStoreDidChangeMessage(message, at: indexPath, for: .update)
                    self.messageDelegate?.signalServiceStoreDidChangeMessages()
                }
            } else {
                NSLog("Error: No chat for message: \(message).")
            }
        } else {
            self.messages.append(message)
            if let chat = self.chat(chatId: message.chatId), let index = chat.visibleMessages.index(of: message) {
                let indexPath = IndexPath(item: index, section: 0)
                DispatchQueue.main.async {
                    self.messageDelegate?.signalServiceStoreDidChangeMessage(message, at: indexPath, for: .insert)
                    self.messageDelegate?.signalServiceStoreDidChangeMessages()
                }
            } else {
                NSLog("Error: No chat for message: \(message).")
            }
        }
    }

    func save(_ chat: SignalChat) throws {
        // Do this first, so we can throw before we call willChange.
        let data = try self.encoder.encode(chat)

        DispatchQueue.main.async {
            self.chatDelegate?.signalServiceStoreWillChangeChats()
        }

        // insert
        if self.chat(chatId: chat.uniqueId) == nil {
            self.persistenceStore?.store(data, key: chat.uniqueId, type: .chat)

            self.chats.append(chat)
            let indexPath = IndexPath(item: self.chats.index(of: chat)!, section: 0)
            DispatchQueue.main.async {
                self.chatDelegate?.signalServiceStoreDidChangeChat(chat, at: indexPath, for: .insert)
            }
        } else {
            // update
            self.persistenceStore?.update(data, key: chat.uniqueId, type: .chat)
            let indexPath = IndexPath(item: self.chats.index(of: chat)!, section: 0)

            DispatchQueue.main.async {
                self.chatDelegate?.signalServiceStoreDidChangeChat(chat, at: indexPath, for: .update)
            }
        }

        DispatchQueue.main.async {
            self.chatDelegate?.signalServiceStoreDidChangeChats()
        }
    }

    func save(attachmentPointer: SignalServiceAttachmentPointer) throws {
        let data = try self.encoder.encode(attachmentPointer)

        if let index = self.attachmentPointers.index(of: attachmentPointer) {
            self.attachmentPointers.delete(element: attachmentPointer)
            self.attachmentPointers.insert(attachmentPointer, at: index)
        } else {
            self.attachmentPointers.append(attachmentPointer)
        }

        self.persistenceStore?.store(data, key: attachmentPointer.uniqueId, type: .attachmentPointer)
    }

    func deleteAllChatsAndMessages() {
        self.chats = []
        self.messages = []
    }
}
