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

    public var attachment: Data? {
        return nil
    }

    public init(body: String, chatId: String) {
        self.body = body
        self.chatId = chatId
        self.attachmentPointerIds = []
    }

    public static func == (lhs: SignalMessage, rhs: SignalMessage) -> Bool {
        guard type(of: lhs) == type(of: rhs) else { return false }

        return lhs.uniqueId == rhs.uniqueId && lhs.timestamp == rhs.timestamp
    }

    public func plaintextData(in chat: SignalChat) -> Data {
        fatalError("Don't call this directly. Should be called only on subclasses")
    }
}
