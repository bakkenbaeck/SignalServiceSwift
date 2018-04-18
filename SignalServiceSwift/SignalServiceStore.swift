//
//  SignalServiceStore.swift
//  SignalServiceSwift
//
//  Created by Igor Ranieri on 17.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation

public protocol SignalMessage: Codable {
    var body: String { get }
    var timestamp: TimeInterval { get }
    var chatId: String { get }
    var uniqueId: String { get }
}

public struct IncomingSignalMessage: SignalMessage {
    public var body: String
    public var chatId: String

    public var timestamp: TimeInterval = Date().timeIntervalSince1970 * 1000.0
    public var uniqueId: String = UUID().uuidString
    public var isRead: Bool = false

    public init?(from data: Data, chatId: String) {
        guard let content = try? Signalservice_Content(serializedData: data) else {
            return nil
        }

        let dataMessage = content.dataMessage

        self.body = dataMessage.body
        self.chatId = chatId
    }
}

public struct OutgoingSignalMessage: SignalMessage {
    public enum MessageState: Int, Codable {
        case none = -1
        case attemptingOut = 0
        case unsent = 1
        case sent = 4
    }

    enum CodingKeys: String, CodingKey {
        case messageState
        case recipientId
        case chatId
        case body
        case timestamp
        case uniqueId
    }

    public var messageState: MessageState = .none
    public var recipientId: String

    public var chatId: String
    public var body: String
    public var timestamp: TimeInterval = Date().timeIntervalSince1970 * 1000.0
    public let uniqueId: String = UUID().uuidString

    // optional with nil value, otherwise it won't let me conform to Codable 👀
    // in practice, we should assume it is not optional.
    public var cipherText: SignalCiphertext? = nil

    public func encryptedBodybase64Encoded() -> String {
        return self.cipherText!.data.base64EncodedString()
    }

    init(recipientId: String, chatId: String, body: String, ciphertext: SignalCiphertext) {
        self.recipientId = recipientId
        self.chatId = chatId
        self.body = body
        self.cipherText = ciphertext
    }
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

public protocol SignalServiceStore {
    func deleteAllChatsAndMessages()

    func save(message: SignalMessage)
    func save(chat: SignalChat)
}
