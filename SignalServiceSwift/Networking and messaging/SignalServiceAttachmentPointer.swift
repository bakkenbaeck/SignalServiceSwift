//
//  SignalServiceAttachmentPointer.swift
//  SignalServiceSwift
//
//  Created by Igor Ranieri on 27.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

struct SignalServiceAttachmentPointer: Equatable, Codable {
    enum State: Int, Codable {
        case enqueued
        case downloading
        case failed
    }

    var serverId: UInt64
    var key: Data
    var digest: Data
    var size: UInt32
    var contentType: String

    var uniqueId: String = UUID().uuidString

    var state: State = .enqueued

    var attachmentData: Data? = nil

    init(serverId: UInt64, key: Data, digest: Data, size: UInt32, contentType: String) {
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
