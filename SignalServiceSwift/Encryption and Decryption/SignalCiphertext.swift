//
//  SignalCiphertext.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 22.03.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

let CurrentVersion: Int32 = 3

/// Wrapper for the signal ciphertext_message.
class SignalCiphertext: NSObject, SignalLibraryMessage {
    var data: Data

    var ciphertextType: CiphertextType

    var ciphertextPointer: UnsafeMutablePointer<ciphertext_message>

    init(_ ciphertext: UnsafeMutablePointer<ciphertext_message>) {
        guard let buffer = ciphertext_message_get_serialized(ciphertext) else {
            fatalError()
        }

        let serializedLength = signal_buffer_len(buffer)
        let serializedData = Data(bytes: signal_buffer_data(buffer), count: serializedLength)

        self.data = serializedData
        self.ciphertextType = CiphertextType(rawValue: ciphertext_message_get_type(ciphertext))
        self.ciphertextPointer = ciphertext
    }

    deinit {
        signal_type_unref(UnsafeMutableRawPointer(self.ciphertextPointer).assumingMemoryBound(to: signal_type_base.self))
    }

    func base64Encoded() -> String {
        return self.data.base64EncodedString()
    }
}
