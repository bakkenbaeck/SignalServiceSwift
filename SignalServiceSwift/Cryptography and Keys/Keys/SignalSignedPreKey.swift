//
//  SignalSignedPreKey.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 21.03.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

/// Wrapper for a signed prekey.
public class SignalSignedPreKey: NSObject {
    public private(set) var signedPreKeyPointer: UnsafeMutablePointer<session_signed_pre_key>

    public lazy var preKeyId: UInt32 = {
        session_signed_pre_key_get_id(self.signedPreKeyPointer)
    }()

    /// Date the signed pre key was generated.
    public lazy var timestamp: Date = {
        let msTimestamp = session_signed_pre_key_get_timestamp(self.signedPreKeyPointer)

        return Date(milisecondTimeIntervalSinceEpoch: msTimestamp)
    }()

    /// Signal serialised signature.
    public lazy var signature: Data = {
        guard let bytes = session_signed_pre_key_get_signature(self.signedPreKeyPointer) else {
            fatalError()
        }
        let length = session_signed_pre_key_get_signature_len(self.signedPreKeyPointer)

        return Data(bytes: bytes, count: length)
    }()

    /// The signed prekey's EC key pair.
    public lazy var keyPair: SignalKeyPair = {
        guard let keyPair = session_signed_pre_key_get_key_pair(self.signedPreKeyPointer) else {
            fatalError()
        }

        return SignalKeyPair(publicKey: keyPair.pointee.public_key, privateKey: keyPair.pointee.private_key)
    }()

    /// The signal serialised signed pre key.
    public lazy var serializedData: Data = {
        var bufferPointer: UnsafeMutablePointer<signal_buffer>?
        let result = session_signed_pre_key_serialize(&bufferPointer, self.signedPreKeyPointer)

        guard result >= 0, let buffer = bufferPointer, let bytes = signal_buffer_data(buffer) else {
            fatalError()
        }

        let length = signal_buffer_len(buffer)
        let data = Data(bytes: bytes, count: length)

        signal_buffer_free(buffer)

        return data
    }()

    /// Init from a valid signed pre key pointer.
    ///
    /// - Parameter signedPreKeyPointer: the signed pre key pointer.
    public init(with signedPreKeyPointer: UnsafeMutablePointer<session_signed_pre_key>) {
        self.signedPreKeyPointer = signedPreKeyPointer
    }

    /// Init from a signal serialised signed pre key data structure.
    ///
    /// - Parameter serializedData: the valid serialised signed pre key.
    public init?(serializedData: Data) {
        var signedPreKeyPointer: UnsafeMutablePointer<session_signed_pre_key>?

        var bytes = [UInt8](repeating: 0, count: serializedData.count)
        serializedData.copyBytes(to: &bytes, count: serializedData.count)

        let result = session_signed_pre_key_deserialize(&signedPreKeyPointer, bytes, serializedData.count, nil)

        guard result >= 0, let signedPreKey = signedPreKeyPointer else {
            return nil
        }

        self.signedPreKeyPointer = signedPreKey
    }

    /// Init from an identity key pair.
    ///
    /// - Parameters:
    ///   - identityKeyPair: Our valid identity key pair.
    ///   - signalContext: The user's signal context.
    public convenience init(withIdentityKeyPair identityKeyPair: SignalIdentityKeyPair, signalContext: SignalContext) {
        var signedPreKeyPointer: UnsafeMutablePointer<session_signed_pre_key>?

        // We reserve UInt32.max as an NSNotFound equivalent.
        let signedPreKeyId = 1 + arc4random_uniform(UInt32.max - 2)
        let timestamp = Date().milisecondTimeIntervalSinceEpoch

        guard signal_protocol_key_helper_generate_signed_pre_key(&signedPreKeyPointer, identityKeyPair.identityKeyPairPointer, signedPreKeyId, timestamp, signalContext.context) == 0 else { fatalError("Could not generate new signed prekey") }

        self.init(with: signedPreKeyPointer!)
    }
}
