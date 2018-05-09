//
//  SignalChat.swift
//  SignalServiceSwift
//
//  Created by Igor Ranieri on 17.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

public class SignalChat: Equatable, Codable {
    enum CodingKeys: String, CodingKey {
        case recipientIdentifier
        case recipientIdentifiers
        case uniqueId
        case name
        case lastArchivalDate
        case currentDraft
        case avatarId
        case isMuted
    }

    var store: SignalServiceStore?
    var contactsDelegate: SignalRecipientsDelegate?

    var avatarId: String?

    var avatarServerId: UInt64 {
        if let avatarId = avatarId {
            return self.store?.attachment(with: avatarId)?.serverId ?? 0
        }

        return 0
    }

    public var image: UIImage? {
        // 1:1 chat
        if let recipientIdentifier = self.recipientIdentifier {
            return self.contactsDelegate?.image(for: recipientIdentifier)
        }

        // group chat
        guard let id = self.avatarId,
            let avatarPointer = self.store?.attachment(with: id),
            let data = avatarPointer.attachmentData,
            let image  = UIImage(data: data)
        else {
            return nil
        }

        return image
    }

    public var displayName: String {
        if self.isGroupChat {
            return self.name
        } else if let recipientIdentifier = self.recipientIdentifier,
            let displayName = self.contactsDelegate?.displayName(for: recipientIdentifier)
        {
            return displayName
        }

        return self.recipientIdentifier ?? self.uniqueId
    }

    public var recipientIdentifier: String?
    public var name: String

    var recipientIdentifiers: [String]

    public var recipients: [SignalAddress]? {
        return self.isGroupChat ? self.store?.recipients(with: self.recipientIdentifiers) : self.store?.recipients(with: [self.recipientIdentifier!])
    }

    public var isGroupChat: Bool {
        return self.recipientIdentifier == nil && self.recipientIdentifiers.count > 1
    }

    public var uniqueId: String = UUID().uuidString

    public var numberOfMessages: Int {
        return self.messages.count
    }

    public var hasUnreadMessages: Bool {
        guard let incoming = self.messages.filter({ message -> Bool in
            message is IncomingSignalMessage
        }) as? [IncomingSignalMessage] else { return false } // no incoming messages

        for message in incoming {
            if !message.isRead {
                return true
            }
        }

        return false
    }

    /// Returns the string that will be displayed typically in a conversations view as a preview of the last message.
    public var lastMessageLabel: String {
        return self.messages.last?.body ?? ""
    }

    /// Returns the latest date of a message in the chat or the chat creation date if there are no messages.
    public var lastMessageDate: Date = Date()

    /// Returns the last date at which chat was archived or nil if it was never archived or it was brought back to the inbox.
    public var lastArchivalDate: Date?

    /// Returns the last known draft for that thread. Always returns a string. Empty string if none.
    public var currentDraft: String = ""

    public var isMuted: Bool = false

    public var visibleMessages: [SignalMessage] {
        return self.messages.filter({ message -> Bool in
            return !message.body.isEmpty || message is InfoSignalMessage
        })
    }

    public var messages: [SignalMessage] {
        return self.store?.messages(for: self) ?? []
    }

    public var isArchived: Bool {
        return (self.lastArchivalDate?.timeIntervalSinceNow ?? 0) > 0
    }

    public init(recipientIdentifier: String, in store: SignalServiceStore) {
        self.recipientIdentifier = recipientIdentifier
        self.name = recipientIdentifier
        self.recipientIdentifiers = []
        self.store = store
    }

    public init(recipientIdentifiers: [String], in store: SignalServiceStore) {
        self.recipientIdentifiers = recipientIdentifiers
        self.recipientIdentifier = nil
        self.name = self.uniqueId
        self.store = store
    }

    public static func == (lhs: SignalChat, rhs: SignalChat) -> Bool {
        return lhs.uniqueId == rhs.uniqueId
    }

    public func archive() {
    }

    public func unarchive() {
    }

    public func markAllAsRead() {
        let incomingMessages = self.messages.compactMap { message -> IncomingSignalMessage? in
            message as? IncomingSignalMessage
        }

        incomingMessages.forEach { incoming in
            incoming.isRead = false
            try? self.store?.save(incoming)
        }
    }
}
