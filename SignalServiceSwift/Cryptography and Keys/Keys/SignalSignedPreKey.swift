//
//  SignalSignedPreKey.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 21.03.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation

public class SignalSignedPreKey: NSObject, NSSecureCoding {
    public static var supportsSecureCoding: Bool {
        return true
    }

    public private(set) var signedPreKeyPointer: UnsafeMutablePointer<session_signed_pre_key>

    public lazy var preKeyId: UInt32 = {
        return session_signed_pre_key_get_id(self.signedPreKeyPointer)
    }()

    public lazy var timestamp: Date = {
        let unixTimestamp = session_signed_pre_key_get_timestamp(self.signedPreKeyPointer);
        let seconds = TimeInterval(Double(unixTimestamp) / 1000.0)

        return Date(timeIntervalSince1970: seconds)
    }()

    public lazy var signature: Data = {
        guard let bytes = session_signed_pre_key_get_signature(self.signedPreKeyPointer) else {
            fatalError()
        }
        let length = session_signed_pre_key_get_signature_len(self.signedPreKeyPointer)

        return  Data(bytes: bytes, count: length)
    }()

    public lazy var keyPair: SignalKeyPair = {
        guard let keyPair = session_signed_pre_key_get_key_pair(self.signedPreKeyPointer) else {
            fatalError()
        }

        return SignalKeyPair(publicKey: keyPair.pointee.public_key, privateKey: keyPair.pointee.private_key)
    }()

    public lazy var serializedData: Data = {
        var bufferPointer: UnsafeMutablePointer<signal_buffer>? = nil
        let result = session_signed_pre_key_serialize(&bufferPointer, self.signedPreKeyPointer)

        guard result >= 0, let buffer = bufferPointer, let bytes = signal_buffer_data(buffer) else {
            fatalError()
        }

        let length = signal_buffer_len(buffer)
        let data = Data(bytes: bytes, count: length)

        return data;
    }()

    public init(with signedPreKeyPointer: UnsafeMutablePointer<session_signed_pre_key>) {
        self.signedPreKeyPointer = signedPreKeyPointer
    }

    public init?(serializedData: Data) {
        var signedPreKeyPointer: UnsafeMutablePointer<session_signed_pre_key>? = nil

        var bytes = [UInt8](repeating:0, count: serializedData.count)
        serializedData.copyBytes(to: &bytes, count: serializedData.count)

        let result = session_signed_pre_key_deserialize(&signedPreKeyPointer, bytes, serializedData.count, nil)

        guard result >= 0, let signedPreKey = signedPreKeyPointer else {
            return nil
        }

        self.signedPreKeyPointer = signedPreKey
    }

    public convenience init(withIdentityKeyPair identityKeyPair: SignalIdentityKeyPair, signalContext: SignalContext) {
        var signedPreKeyPointer: UnsafeMutablePointer<session_signed_pre_key>? = nil

        // We reserve UInt32.max as an NSNotFound equivalent.
        let signedPreKeyId = 1 + arc4random_uniform(UInt32.max - 2)
        let timestamp = UInt64(Date().timeIntervalSince1970 * 1000)

        guard signal_protocol_key_helper_generate_signed_pre_key(&signedPreKeyPointer, identityKeyPair.identityKeyPairPointer, signedPreKeyId, timestamp, signalContext.context) == 0 else { fatalError("Could not generate new signed pre key") }

        self.init(with: signedPreKeyPointer!)
    }

    public required convenience init?(coder aDecoder: NSCoder) {
        guard let data = aDecoder.decodeObject(forKey: "data") as? Data else {
            return nil
        }

        self.init(serializedData: data)
    }

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(self.serializedData, forKey: "data")
    }
}
