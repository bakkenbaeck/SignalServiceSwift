//
//  SignalMessageProtocol.swift
//  SignalServiceSwift
//
//  Created by Igor Ranieri on 18.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

/// The base signal message class.
public class SignalMessage: Codable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case body,
            chatId,
            uniqueId,
            timestamp,
            attachmentPointerIds
    }

    // var store: SignalServiceStore? = nil

    /// The message plaintext body.
    public var body: String

    // The thread in which our message was sent/received.
    public var chatId: String

    // Unique identifier, for the database.
    public var uniqueId: String = UUID().uuidString

    // Milisecond time interval, for security reasons.
    public var timestamp: UInt64 = Date().milisecondTimeIntervalSinceEpoch

    /// Id of all our attachments.
    public var attachmentPointerIds: [String]

    var store: SignalServiceStore?

    private var cachedAttachment: Data?

    public var attachment: Data? {
        if let data = self.cachedAttachment {
            return data
        } else if let id = self.attachmentPointerIds.first {
            self.cachedAttachment = self.store?.attachment(with: id)?.attachmentData
        }

        return self.cachedAttachment
    }

    public init(body: String, chatId: String, store: SignalServiceStore) {
        self.body = body
        self.chatId = chatId
        self.attachmentPointerIds = []
        self.store = store
    }

    public static func == (lhs: SignalMessage, rhs: SignalMessage) -> Bool {
        guard type(of: lhs) == type(of: rhs) else { return false }

        return lhs.uniqueId == rhs.uniqueId && lhs.timestamp == rhs.timestamp
    }

    public func plaintextData(in chat: SignalChat) -> Data {
        fatalError("Don't call this directly. Should be called only on subclasses")
    }
}
