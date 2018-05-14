//
//  OutgoingSignalMessage.swift
//  SignalServiceSwift
//
//  Created by Igor Ranieri on 18.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

/// Request group information, such as member list, name, avatar… Should not be stored.
public class SyncGroupRequestSignalMessage: OutgoingSignalMessage {
    public init(for chat: SignalChat, store: SignalServiceStore) {
        super.init(recipientId: chat.uniqueId, chatId: chat.uniqueId, body: "", store: store)
    }

    public required init(from decoder: Decoder) throws {
        fatalError("Should not be stored")
    }

    public override func plaintextData(in chat: SignalChat) -> Data {
        var groupContet = Signalservice_GroupContext()
        groupContet.type = .requestInfo
        groupContet.id = self.chatId.data(using: .utf8)!

        var dataMessage = Signalservice_DataMessage()
        dataMessage.group = groupContet

        var signalContent = Signalservice_Content()
        signalContent.dataMessage = dataMessage

        let plaintextData = try! signalContent.serializedData()

        return (plaintextData as NSData).paddedMessageBody()!
    }
}

public class ReadReceiptSignalMessage: OutgoingSignalMessage {
    public var message: IncomingSignalMessage

    public init(message: IncomingSignalMessage, store: SignalServiceStore) {
        self.message = message

        super.init(recipientId: message.senderId, chatId: message.chatId, body: "", store: store)
    }

    public required init(from decoder: Decoder) throws {
        fatalError("Not supposed to be stored!")
    }

    public override func plaintextData(in chat: SignalChat) -> Data {
        var syncProto = Signalservice_SyncMessage()
        var readProto = Signalservice_SyncMessage.Read()

        readProto.sender = self.message.senderId
        readProto.timestamp = self.message.timestamp

        syncProto.read = [readProto]

        return try! syncProto.serializedData()
    }
}

public class TranscriptSignalMessage: OutgoingSignalMessage {
    public var message: OutgoingSignalMessage

    public init(message: OutgoingSignalMessage, store: SignalServiceStore) {
        self.message = message

        super.init(recipientId: message.recipientId, chatId: message.chatId, body: message.body, store: store)
    }

    public required init(from decoder: Decoder) throws {
        fatalError("Not supposed to be stored!")
    }

    public override func plaintextData(in chat: SignalChat) -> Data {
        var syncProto = Signalservice_SyncMessage()
        var sentProto = Signalservice_SyncMessage.Sent()

        sentProto.timestamp = self.message.timestamp
        sentProto.destination = self.message.recipientId
        sentProto.message = self.message.signalDataMessage(in: chat)
        sentProto.expirationStartTimestamp = self.message.timestamp

        syncProto.sent = sentProto

        return try! syncProto.serializedData()
    }
}

/// Our base outgoing message.
public class OutgoingSignalMessage: SignalMessage {
    public enum MessageState: Int, Codable {
        case none = -1
        case attemptingOut = 0
        case unsent = 1
        case sent = 4
    }

    public enum MessageType: Int {
        case unknown
        case encryptedWhisper
        case ignoredWhisper // this is only required by the android client, we don't need it
        case preKeyWhisper
        case unencryptedWhisper

        // TODO: Add remaining types! Check group messages!
        public init(_ raw: CiphertextType) {
            switch raw {
            case .message:
                self = .encryptedWhisper
            case .preKeyMessage:
                self = .preKeyWhisper
            default:
                self = .unknown
            }
        }
    }

    public override var attachment: Data? {
        if let id = self.attachmentPointerIds.first {
            return self.store?.attachment(with: id)?.attachmentData
        }

        return super.attachment
    }

    var store: SignalServiceStore?

    public enum GroupMetaMessageType: Int, Codable {
        case none
        case new
        case update
        case deliver
        case quit
        case requestInfo
    }

    enum CodingKeys: String, CodingKey {
        case messageState
        case recipientId
        case groupMetaMessageType
        case body,
            chatId,
            uniqueId,
            timestamp,
            attachmentPointerIds
    }

    public var didSentSyncTranscript = false

    public var groupMetaMessageType: GroupMetaMessageType
    public var messageState: MessageState = .none
    public var recipientId: String

    public init(recipientId: String, chatId: String, body: String, groupMessageType: GroupMetaMessageType = .none, store: SignalServiceStore) {
        self.recipientId = recipientId
        self.groupMetaMessageType = groupMessageType

        super.init(body: body, chatId: chatId)

        self.store = store
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: OutgoingSignalMessage.CodingKeys.self)

        self.groupMetaMessageType = try container.decode(GroupMetaMessageType.self, forKey: .groupMetaMessageType)
        self.messageState = try container.decode(MessageState.self, forKey: .messageState)
        self.recipientId = try container.decode(String.self, forKey: .recipientId)

        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: OutgoingSignalMessage.CodingKeys.self)

        try container.encode(self.messageState, forKey: OutgoingSignalMessage.CodingKeys.messageState)
        try container.encode(self.recipientId, forKey: OutgoingSignalMessage.CodingKeys.recipientId)
        try container.encode(self.groupMetaMessageType, forKey: OutgoingSignalMessage.CodingKeys.groupMetaMessageType)

        try super.encode(to: encoder)
    }

    public override func plaintextData(in chat: SignalChat) -> Data {
        // Now it's time for the protobuff russian doll.
        var signalContent = Signalservice_Content()
        signalContent.dataMessage = self.signalDataMessage(in: chat)

        let plaintextData = try! signalContent.serializedData()

        return (plaintextData as NSData).paddedMessageBody()!
    }

    func signalDataMessage(in chat: SignalChat) -> Signalservice_DataMessage {
        var signalDataMessage = Signalservice_DataMessage()
        signalDataMessage.body = self.body

        if chat.isGroupChat {
            var groupContext = Signalservice_GroupContext()

            switch self.groupMetaMessageType {
            case .quit:
                groupContext.type = .quit
            case .new, .update:
                if let id = self.attachmentPointerIds.first, let pointer = self.store?.attachment(with: id) {
                    groupContext.avatar = self.attachmentProto(from: pointer)
                }

                groupContext.members = chat.recipientIdentifiers
                groupContext.name = chat.name
                groupContext.type = .update
            case .requestInfo:
                groupContext.type = .requestInfo
            default:
                groupContext.type = .deliver
            }

            groupContext.id = chat.uniqueId.data(using: .utf8)!
            signalDataMessage.group = groupContext
        }

        var attachments: [Signalservice_AttachmentPointer] = []
        for id in self.attachmentPointerIds {
            if let pointer = self.store?.attachment(with: id) {
                attachments.append(self.attachmentProto(from: pointer))
            }
        }

        signalDataMessage.attachments = attachments

        return signalDataMessage
    }

    private func attachmentProto(from pointer: SignalServiceAttachmentPointer) -> Signalservice_AttachmentPointer {
        var proto = Signalservice_AttachmentPointer()
        proto.id = pointer.serverId
        proto.contentType = pointer.contentType
        proto.size = pointer.size
        proto.key = pointer.key
        proto.digest = pointer.digest

        return proto
    }
}
