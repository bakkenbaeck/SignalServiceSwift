//
//  SignalChat.swift
//  SignalServiceSwift
//
//  Created by Igor Ranieri on 17.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation

public class SignalChat: Equatable, Codable {
    enum CodingKeys: String, CodingKey {
        case recipientIdentifier,
        uniqueId,
        lastArchivalDate,
        currentDraft,
        isMuted
    }

    public var recipientIdentifier: String

    public var uniqueId: String = UUID().uuidString

    public var numberOfMessages: Int {
        return self.messages.count
    }

    public var hasUnreadMessages: Bool {
        guard let incoming = self.messages.filter({ message -> Bool in
            return message is IncomingSignalMessage
        }) as? [IncomingSignalMessage] else { return false } // no incoming messages

        for message in incoming {
            if !message.isRead {
                return true
            }
        }

        return false
    }

    private var store: SignalServiceStore?

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

    public var messages: [SignalMessage] {
        return self.store?.messages(for: self) ?? []
    }

    public var isArchived: Bool {
        return (self.lastArchivalDate?.timeIntervalSinceNow ?? 0) > 0
    }

    public class func fetchOrCreateChat(with recipientIdentifier: String, in store: SignalServiceStore) -> SignalChat {
        if let chat = store.chat(recipientIdentifier: recipientIdentifier) {
            return chat
        } else  {
            let chat = SignalChat(recipientIdentifier: recipientIdentifier, in: store)
            store.save(chat: chat)

            return chat
        }
    }

    public init(recipientIdentifier: String, in store: SignalServiceStore) {
        self.recipientIdentifier = recipientIdentifier
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

    }
}
