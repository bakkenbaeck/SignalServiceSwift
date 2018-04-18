//
//  SignalCipherMessage.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 22.03.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation

public enum CiphertextType: Int32 {
    case unknown
    case message = 2
    case preKeyMessage = 3

    public init(rawValue: Int32) {
        switch rawValue {
        case 3:
            self = .preKeyMessage
        case 2:
            self = .message
        default:
            self = .unknown
        }
    }
}

public protocol SignalCipherMessageProtocol {
    var data: Data { get set }
    var ciphertextType: CiphertextType { get set }
}

public class SignalCipherMessage: NSObject, SignalCipherMessageProtocol {
    public var data: Data

    public var ciphertextType: CiphertextType

    @objc public private(set) var signalMessagePointer: UnsafeMutablePointer<signal_message>?

    public init?(data: Data, context: SignalContext) {
        let nsData = data as NSData
        let result = signal_message_deserialize(&self.signalMessagePointer, nsData.bytes.assumingMemoryBound(to: UInt8.self), data.count, context.context)


        guard result >= 0, let signalMessagePointer = self.signalMessagePointer else {
            return nil
        }

        self.data = data
        self.ciphertextType = CiphertextType(rawValue: ciphertext_message_get_type(&signalMessagePointer.pointee.base_message))
    }
}

public class SignalPreKeyMessage: NSObject, SignalCipherMessageProtocol {
    public var data: Data

    public var ciphertextType: CiphertextType

    @objc public private(set) var preKeySignalMessagePointer: UnsafeMutablePointer<pre_key_signal_message>?

    public init?(data: Data, context: SignalContext) {
        let nsData = data as NSData
        let result = pre_key_signal_message_deserialize(&self.preKeySignalMessagePointer, nsData.bytes.assumingMemoryBound(to: UInt8.self), data.count, context.context)

        guard result >= 0, let preKeySignalMessagePointer = self.preKeySignalMessagePointer else {
            return nil
        }

        self.data = data
        self.ciphertextType = CiphertextType(rawValue: ciphertext_message_get_type(&preKeySignalMessagePointer.pointee.base_message))
    }
}
