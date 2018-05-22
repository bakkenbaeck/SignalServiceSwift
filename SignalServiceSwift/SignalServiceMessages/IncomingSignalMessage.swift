//
//  IncomingSignalMessage.swift
//  SignalServiceSwift
//
//  Created by Igor Ranieri on 18.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

/// Our base incoming message.
public class IncomingSignalMessage: SignalMessage {
    public var isRead: Bool = false

    public var isSent: Bool = false

    public var senderId: String

    enum CodingKeys: String, CodingKey {
        case isRead
        case isSent
        case senderId
        case body,
            chatId,
            uniqueId,
            timestamp,
            attachmentPointerIds
    }

    public init(body: String, chatId: String, senderId: String, timestamp: UInt64, store: SignalServiceStore) {
        self.senderId = senderId

        super.init(body: body, chatId: chatId, store: store)

        self.timestamp = timestamp
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.isRead = try container.decode(Bool.self, forKey: .isRead)
        self.isSent = try container.decode(Bool.self, forKey: .isSent)
        self.senderId = try container.decode(String.self, forKey: .senderId)

        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.isRead, forKey: CodingKeys.isRead)
        try container.encode(self.isSent, forKey: CodingKeys.isSent)
        try container.encode(self.senderId, forKey: CodingKeys.senderId)

        try super.encode(to: encoder)
    }
}
