//
//  SignalServiceStore.swift
//  SignalServiceSwift
//
//  Created by Igor Ranieri on 17.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

public protocol PersistenceStore: SignalLibraryStoreDelegate {
    func retrieveAllObjects(ofType type: SignalServiceStore.PersistedType) -> [Data]

    func retrieveObject(ofType type: SignalServiceStore.PersistedType, key: String) -> Data?

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
        case sender
    }

    public var chatDelegate: SignalServiceStoreChatDelegate?
    public var messageDelegate: SignalServiceStoreMessageDelegate?
    public var contactsDelegate: SignalRecipientsDisplayDelegate

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private var chats: [SignalChat] = []

    private var messages: [SignalMessage] = []

    private var recipients: [SignalAddress] = []

    private var attachmentPointers: [SignalServiceAttachmentPointer] = []

    private var persistenceStore: PersistenceStore?

    public init(persistenceStore: PersistenceStore? = nil, contactsDelegate: SignalRecipientsDisplayDelegate) {
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

    func fetchSender() -> SignalSender? {
        guard let data = self.persistenceStore?.retrieveObject(ofType: .sender, key: "sender") else { return nil }
        let sender = try? self.decoder.decode(SignalSender.self, from: data)

        return sender
    }

    func storeSender(_ sender: SignalSender) {
        guard let data = try? self.encoder.encode(sender) else { return }
        self.persistenceStore?.store(data, key: "sender", type: .sender)
    }

    func fetchOrCreateRecipient(name: String, deviceId: Int32) -> SignalAddress {
        let recipient: SignalAddress

        if let data = self.persistenceStore?.retrieveObject(ofType: .recipient, key: name),
            let existingRecipient = try? self.decoder.decode(SignalAddress.self, from: data)
        {
            recipient = existingRecipient
        } else {
            recipient = SignalAddress(name: name, deviceId: deviceId)

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
        guard let data = self.persistenceStore?.retrieveObject(ofType: .attachmentPointer, key: id),
            let pointer = try? self.decoder.decode(SignalServiceAttachmentPointer.self, from: data)
            else {
                return nil
        }

        return pointer
    }

    public func fetchAllChats() -> [SignalChat] {
        guard let dataAry = self.persistenceStore?.retrieveAllObjects(ofType: .chat) else { return [] }

        return dataAry.compactMap({ data in
            let chat = try? self.decoder.decode(SignalChat.self, from: data)
            chat?.store = self

            return chat
        })
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
        let messages = self.fetchMessages()
        let chatMessages = messages.compactMap({ message -> SignalMessage? in
            message.chatId == chat.uniqueId ? message : nil
        }).sorted { (a, b) -> Bool in
            a.timestamp < b.timestamp
        }

        return chatMessages
    }

    func fetchMessages() -> [SignalMessage] {
        guard let persistenceStore = self.persistenceStore else { return [] }

        let info: [SignalMessage] = persistenceStore.retrieveAllObjects(ofType: .infoMessage).compactMap { data in
            try? self.decoder.decode(InfoSignalMessage.self, from: data)
        }

        let incoming: [SignalMessage] = persistenceStore.retrieveAllObjects(ofType: .incomingMessage).compactMap { data in
            try? self.decoder.decode(IncomingSignalMessage.self, from: data)
        }

        let outgoing: [SignalMessage] = persistenceStore.retrieveAllObjects(ofType: .outgoingMessage).compactMap { data in
            try? self.decoder.decode(OutgoingSignalMessage.self, from: data)
        }

        let messages = info + incoming + outgoing

        return messages
    }

    func save(_ recipient: SignalAddress) throws {
        let data = try self.encoder.encode(recipient)

        self.recipients.append(recipient)
        self.persistenceStore?.store(data, key: recipient.name, type: .recipient)
    }

    func save(_ message: SignalMessage) throws {
        let messageDataAndType: (data: Data, type: PersistedType)

        if let message = message as? OutgoingSignalMessage {
            messageDataAndType.data = try self.encoder.encode(message)
            messageDataAndType.type = .outgoingMessage
        } else if let message = message as? IncomingSignalMessage {
            messageDataAndType.data = try self.encoder.encode(message)
            messageDataAndType.type = .incomingMessage
        } else if let message = message as? InfoSignalMessage {
            messageDataAndType.data = try self.encoder.encode(message)
            messageDataAndType.type = .infoMessage
        } else {
            fatalError("Unsupported message type: \(message)")
        }

        // update?
        if self.messages.contains(where: { msg -> Bool in msg.uniqueId == message.uniqueId}) {
            self.persistenceStore?.store(messageDataAndType.data, key: message.uniqueId, type: messageDataAndType.type)

            if let chat = self.chat(chatId: message.chatId) {
                guard let index = chat.visibleMessages.index(of: message) else {
                    NSLog("Message type visible in chat.")
                    return
                }

                let indexPath = IndexPath(item: index, section: 0)
                DispatchQueue.main.async {
                    self.messageDelegate?.signalServiceStoreWillChangeMessages()
                    self.messageDelegate?.signalServiceStoreDidChangeMessage(message, at: indexPath, for: .update)
                    self.messageDelegate?.signalServiceStoreDidChangeMessages()
                }
            } else {
                NSLog("Error: No chat for message: \(message).")
            }
        } else {
            DispatchQueue.main.async {
                self.messageDelegate?.signalServiceStoreWillChangeMessages()

                self.messages.append(message)
                self.persistenceStore?.store(messageDataAndType.data, key: message.uniqueId, type: messageDataAndType.type)

                if let chat = self.chat(chatId: message.chatId) {
                    guard let index = chat.visibleMessages.index(of: message) else {
                        NSLog("Message type visible in chat.")
                        return
                    }

                    let indexPath = IndexPath(item: index, section: 0)

                    self.messageDelegate?.signalServiceStoreDidChangeMessage(message, at: indexPath, for: .insert)

                } else {
                    NSLog("Error: No chat for message: \(message).")
                }

                self.messageDelegate?.signalServiceStoreDidChangeMessages()
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
            self.chats.append(chat)
            self.persistenceStore?.store(data, key: chat.uniqueId, type: .chat)

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
        self.attachmentPointers.append(attachmentPointer)
        self.persistenceStore?.store(data, key: attachmentPointer.uniqueId, type: .attachmentPointer)
    }

    func deleteAllChatsAndMessages() {
        //TODO: delete stuff
    }
}
