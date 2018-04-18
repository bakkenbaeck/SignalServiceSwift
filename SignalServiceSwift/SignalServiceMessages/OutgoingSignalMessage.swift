//
//  OutgoingSignalMessage.swift
//  SignalServiceSwift
//
//  Created by Igor Ranieri on 18.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation

public class OutgoingSignalMessage: SignalMessage {
    public enum MessageState: Int, Codable {
        case none = -1
        case attemptingOut = 0
        case unsent = 1
        case sent = 4
    }

    enum CodingKeys: String, CodingKey {
        case messageState
        case recipientId
    }

    public var messageState: MessageState = .none
    public var recipientId: String

    // optional with nil value, otherwise it won't let me conform to Codable 👀
    // in practice, we should assume it is not optional.
    public var ciphertext: SignalCiphertext? = nil

    public func encryptedBodybase64Encoded() -> String {
        return self.ciphertext!.data.base64EncodedString()
    }

    init(recipientId: String, chatId: String, body: String, ciphertext: SignalCiphertext) {
        self.recipientId = recipientId
        self.ciphertext = ciphertext

        super.init(body: body, chatId: chatId)

    }

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.messageState = try container.decode(MessageState.self, forKey: .messageState)
        self.recipientId = try container.decode(String.self, forKey: .recipientId)

        try super.init(from: decoder)
    }
}
