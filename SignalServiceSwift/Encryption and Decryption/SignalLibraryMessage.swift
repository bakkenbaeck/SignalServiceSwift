//
//  SignalCipherMessage.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 22.03.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

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

protocol SignalLibraryMessage {
    var data: Data { get set }
    var ciphertextType: CiphertextType { get set }
}

class SignalLibraryCiphertextMessage: NSObject, SignalLibraryMessage {
    var data: Data

    var ciphertextType: CiphertextType

    @objc private(set) var signalMessagePointer: UnsafeMutablePointer<signal_message>

    init?(data: Data, context: SignalContext) {
        let nsData = data as NSData

        var signalMessagePointer: UnsafeMutablePointer<signal_message>?
        let result = signal_message_deserialize(&signalMessagePointer, nsData.bytes.assumingMemoryBound(to: UInt8.self), data.count, context.context)

        guard result >= 0, let signalMessage = signalMessagePointer else {
            return nil
        }

        self.signalMessagePointer = signalMessage
        self.data = data
        self.ciphertextType = CiphertextType(rawValue: ciphertext_message_get_type(&signalMessage.pointee.base_message))
    }

    deinit {
        signal_message_destroy(UnsafeMutableRawPointer(self.signalMessagePointer).assumingMemoryBound(to: signal_type_base.self))
    }
}

public class SignalLibraryPreKeyMessage: NSObject, SignalLibraryMessage {
    public var data: Data

    public var ciphertextType: CiphertextType

    @objc public private(set) var preKeySignalMessagePointer: UnsafeMutablePointer<pre_key_signal_message>

    public init?(data: Data, context: SignalContext) {
        let nsData = data as NSData

        var preKeySignalMessagePointer: UnsafeMutablePointer<pre_key_signal_message>?
        let result = pre_key_signal_message_deserialize(&preKeySignalMessagePointer, nsData.bytes.assumingMemoryBound(to: UInt8.self), data.count, context.context)

        guard result >= 0, let preKeySignalMessage = preKeySignalMessagePointer else {
            return nil
        }

        self.preKeySignalMessagePointer = preKeySignalMessage
        self.data = data
        self.ciphertextType = CiphertextType(rawValue: ciphertext_message_get_type(&preKeySignalMessage.pointee.base_message))
    }

    deinit {
        pre_key_signal_message_destroy(UnsafeMutableRawPointer(self.preKeySignalMessagePointer).assumingMemoryBound(to: signal_type_base.self))
    }
}
