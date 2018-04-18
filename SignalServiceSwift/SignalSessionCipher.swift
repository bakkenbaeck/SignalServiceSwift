//
//  SignalSessionCipher.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 22.03.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation

@objc public class SignalSessionCipher: NSObject {
    public let context: SignalContext
    public let address: SignalAddress

    // This is computed, because the session record can change state, in which case, we might get a different remote registration id.
    public var remoteRegistrationId: UInt32 {
        guard let data = self.context.store.sessionStore.sessionRecord(for: self.address),
            let sessionRecord = SessionRecord(data: data, signalContext: self.context)
            else { return UInt32.max }

        return sessionRecord.remoteRegistrationId
    }

    private var addressPointer: signal_protocol_address

    public var cipher: UnsafeMutablePointer<session_cipher>?

    public init(address: SignalAddress, context: SignalContext) {
        self.context = context
        self.address = address

        self.addressPointer = address.address

        let result = session_cipher_create(&self.cipher, context.store.storeContextPointer, &self.addressPointer, context.context)

        super.init()

        guard result >= 0 && self.cipher != nil else {
            fatalError()
        }
    }

    public func encrypt(message: String) throws -> SignalCiphertext? {
        // Now it's time for the protobuff russian doll.
        var signalDataMessage = Signalservice_DataMessage()
        signalDataMessage.body = message
        signalDataMessage.expireTimer = 0

        var signalContent = Signalservice_Content()
        signalContent.dataMessage = signalDataMessage

        let plaintextData = try! signalContent.serializedData()

        let paddedData = (plaintextData as NSData).paddedMessageBody()!

        var ciphertextPointer: UnsafeMutablePointer<ciphertext_message>? = nil
        var bytes = [UInt8](repeating:0, count: paddedData.count)
        paddedData.copyBytes(to: &bytes, count: paddedData.count)

        let result = session_cipher_encrypt(self.cipher, &bytes, bytes.count, &ciphertextPointer)

        guard result >= 0, let ciphertext = ciphertextPointer else {
            throw ErrorFromSignalError((SignalErrorFromCode(result)))
        }

        let encrypted = SignalCiphertext(message: message, ciphertext)

        return encrypted
    }

    public func decrypt(cipher: SignalCiphertext, ciphertextType: CiphertextType = .unknown) throws -> Data? {
        var buffer: UnsafeMutablePointer<signal_buffer>? = nil
        var result = SG_ERR_UNKNOWN
        
        if let message = SignalCipherMessage(data: cipher.data, context: self.context) {
            result = session_cipher_decrypt_signal_message(self.cipher, message.signalMessagePointer, nil, &buffer)
        } else if let preKeyMessage = SignalPreKeyMessage(data: cipher.data, context: self.context) {
            result = session_cipher_decrypt_pre_key_signal_message(self.cipher, preKeyMessage.preKeySignalMessagePointer, nil, &buffer)
        }

        if result < 0 || buffer == nil {
            throw ErrorFromSignalError(SignalErrorFromCode(result))
        }

        let outData = (Data(bytes: signal_buffer_data(buffer)!, count: signal_buffer_len(buffer)) as NSData).removePadding()

        signal_buffer_free(buffer)

        return outData
    }
}

