//
//  SignalSessionCipher.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 22.03.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

/// Encrypts and decrypts messages.
class SignalSessionCipher: NSObject {
    let context: SignalContext
    let address: SignalAddress

    // This is computed, because the session record can change state, in which case, we might get a different remote registration id.
    var remoteRegistrationId: UInt32 {
        let data = self.context.store.sessionStore.sessionRecord(for: self.address)

        let sessionRecord = SessionRecord(data: data, signalContext: self.context)

        return sessionRecord.remoteRegistrationId
    }

    var addressPointer: UnsafeMutablePointer<signal_protocol_address>

    /// Used to actually encrypt/decrypt the messages.
    var cipher: UnsafeMutablePointer<session_cipher>?

    init(address: SignalAddress, context: SignalContext) {
        self.context = context
        self.address = address

        self.addressPointer = address.addressPointer

        let result = session_cipher_create(&self.cipher, context.store.storeContextPointer, self.addressPointer, context.context)

        super.init()

        guard result >= 0 && self.cipher != nil else {
            fatalError()
        }
    }

    func encrypt(message: OutgoingSignalMessage, in chat: SignalChat) throws -> SignalCiphertext {
        let plaintextData = message.plaintextData(in: chat)

        var ciphertextPointer: UnsafeMutablePointer<ciphertext_message>?
        var bytes = [UInt8](repeating: 0, count: plaintextData.count)
        plaintextData.copyBytes(to: &bytes, count: plaintextData.count)

//        var record: UnsafeMutablePointer<session_record>? = nil
//        var state: UnsafeMutablePointer<session_state>? = nil
//        var message_keys = ratchet_message_keys()
        let result = session_cipher_encrypt(self.cipher, &bytes, bytes.count, &ciphertextPointer)

        guard result >= 0, let ciphertext = ciphertextPointer else {
            throw ErrorFromSignalError((SignalErrorFromCode(result)))
        }

        let encrypted = SignalCiphertext(ciphertext)

        return encrypted
    }

    func decrypt(cipher: SignalLibraryMessage, ciphertextType: CiphertextType = .unknown) throws -> Data? {
        var buffer: UnsafeMutablePointer<signal_buffer>?
        var result = SG_ERR_UNKNOWN

        if let message = SignalLibraryCiphertextMessage(data: cipher.data, context: self.context) {
            result = session_cipher_decrypt_signal_message(self.cipher, message.signalMessagePointer, nil, &buffer)
        } else if let preKeyMessage = SignalLibraryPreKeyMessage(data: cipher.data, context: self.context) {
            result = session_cipher_decrypt_pre_key_signal_message(self.cipher, preKeyMessage.preKeySignalMessagePointer, nil, &buffer)
        }

        if result < 0 || buffer == nil {
            throw ErrorFromSignalError(SignalErrorFromCode(result))
        }

        let outData = (Data(bytes: signal_buffer_data(buffer), count: signal_buffer_len(buffer)) as NSData).removePadding()

        signal_buffer_free(buffer)

        return outData
    }
}
