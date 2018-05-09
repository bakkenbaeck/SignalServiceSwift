//
//  SignalPreKey.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 21.03.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

/// Wrapper for a signal prekey object.
@objc public class SignalPreKey: NSObject {
    public lazy var preKeyId: UInt32 = {
        session_pre_key_get_id(self.preKeyPointer)
    }()

    /// The prekey's EC key pair.
    public lazy var keyPair: SignalKeyPair = {
        guard let keyPair = session_pre_key_get_key_pair(self.preKeyPointer) else { fatalError() }

        return SignalKeyPair(publicKey: keyPair.pointee.public_key, privateKey: keyPair.pointee.private_key)
    }()

    private(set) var preKeyPointer: UnsafeMutablePointer<session_pre_key>

    /// Signal serialised prekey.
    public lazy var serializedData: Data = {
        var bufferPointer: UnsafeMutablePointer<signal_buffer>?
        let result = session_pre_key_serialize(&bufferPointer, self.preKeyPointer)

        guard result >= 0, let buffer = bufferPointer, let bytes = signal_buffer_data(buffer) else {
            fatalError()
        }

        let length = signal_buffer_len(buffer)
        let data = Data(bytes: bytes, count: length)

        signal_buffer_free(buffer)

        return data
    }()

    /// Init from a prekey pointer.
    ///
    /// - Parameter preKey: pointer to a valid prekey.
    public init(withPreKey preKey: UnsafeMutablePointer<session_pre_key>) {
        self.preKeyPointer = preKey
    }

    /// Init from signal serialised prekey data.
    ///
    /// - Parameter serializedData: the serialised prekey data.
    public init?(withSerializedData serializedData: NSData) {
        var preKeyPointer: UnsafeMutablePointer<session_pre_key>?
        let bytes = serializedData.bytes.assumingMemoryBound(to: UInt8.self)
        let result = session_pre_key_deserialize(&preKeyPointer, bytes, serializedData.length, nil)

        guard result >= 0, let preKey = preKeyPointer else {
            return nil
        }

        self.preKeyPointer = preKey
    }

    deinit {
        session_pre_key_destroy(UnsafeMutableRawPointer(self.preKeyPointer).assumingMemoryBound(to: signal_type_base.self))
    }
}
