//
//  SignalPreKey.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 21.03.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation

@objc public class SignalPreKey: NSObject, NSSecureCoding {
    public lazy var preKeyId: UInt32 = {
        session_pre_key_get_id(self.preKey)
    }()

    public lazy var keyPair: SignalKeyPair = {
        guard let keyPair = session_pre_key_get_key_pair(self.preKey) else { fatalError() }

        return SignalKeyPair(publicKey: keyPair.pointee.public_key, privateKey: keyPair.pointee.private_key)
    }()

    private(set) var preKey: UnsafeMutablePointer<session_pre_key>

    public lazy var serializedData: Data = {
        var bufferPointer: UnsafeMutablePointer<signal_buffer>? = nil
        let result = session_pre_key_serialize(&bufferPointer, self.preKey);

        guard result >= 0, let buffer = bufferPointer, let bytes = signal_buffer_data(buffer) else {
            fatalError()
        }

        let length = signal_buffer_len(buffer)
        let data = Data(bytes: bytes, count: length)

        return data;
    }()

    public static var supportsSecureCoding: Bool {
        return  true
    }

    public init(withPreKey preKey: UnsafeMutablePointer<session_pre_key>) {
        self.preKey = preKey
    }

    public init?(withSerializedData serializedData: NSData) {
        var preKeyPointer: UnsafeMutablePointer<session_pre_key>? = nil
        let bytes = serializedData.bytes.assumingMemoryBound(to: UInt8.self)
        let result = session_pre_key_deserialize(&preKeyPointer, bytes, serializedData.length, nil)
        
        guard result >= 0, let preKey = preKeyPointer else {
            return nil
        }

        self.preKey = preKey
    }

    public required convenience init?(coder aDecoder: NSCoder) {
        guard let data = aDecoder.decodeObject(forKey: "data") as? NSData else {
            return nil
        }

        self.init(withSerializedData: data)
    }

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(self.serializedData, forKey: "data")
    }

}
