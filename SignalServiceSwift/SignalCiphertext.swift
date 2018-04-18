//
//  SignalCiphertext.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 22.03.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation

let CurrentVersion: Int32 = 3

public class SignalCiphertext: NSObject, SignalCipherMessageProtocol {
    public var data: Data

    public var ciphertextType: CiphertextType

    public var ciphertextPointer: UnsafeMutablePointer<ciphertext_message>

    public var message: String

    public init(message: String, _ ciphertext: UnsafeMutablePointer<ciphertext_message>) {
        guard let buffer = ciphertext_message_get_serialized(ciphertext) else {
                fatalError()
        }

        let serializedLength = signal_buffer_len(buffer)
        let serializedData = Data(bytes: signal_buffer_data(buffer), count: serializedLength)

        self.data = serializedData
        self.ciphertextType = CiphertextType(rawValue: ciphertext_message_get_type(ciphertext))
        self.ciphertextPointer = ciphertext
        self.message = message
    }
}
