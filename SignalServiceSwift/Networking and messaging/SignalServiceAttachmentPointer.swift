//
//  SignalServiceAttachmentPointer.swift
//  SignalServiceSwift
//
//  Created by Igor Ranieri on 27.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

public struct SignalServiceAttachmentPointer: Equatable, Codable {
    public enum State: Int, Codable {
        case enqueued
        case downloading
        case failed
    }

    public var serverId: UInt64
    public var key: Data
    public var digest: Data
    public var size: UInt32
    public var contentType: String

    public var uniqueId: String = UUID().uuidString

    public var state: State = .enqueued

    public var attachmentData: Data? = nil

    public init(serverId: UInt64, key: Data, digest: Data, size: UInt32, contentType: String) {
        self.serverId = serverId
        self.key = key
        self.digest = digest
        self.size = size
        self.contentType = contentType
    }

    public static func == (lhs: SignalServiceAttachmentPointer, rhs: SignalServiceAttachmentPointer) -> Bool {
        return lhs.uniqueId == rhs.uniqueId
    }
}
