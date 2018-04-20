//
//  SignalKeyPair.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 20.03.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation

@objc public class SignalKeyPair: NSObject {

    @objc public lazy var privateKey: Data = {
        let data: Data
        let privateKeyPointer = self.keyPairPointer.pointee.private_key

        var bufferPointer: UnsafeMutablePointer<signal_buffer>? = nil
        let result = ec_private_key_serialize(&bufferPointer, privateKeyPointer)

        if result == 0, let buffer = bufferPointer, let bytes = signal_buffer_data(buffer) {
            let length = signal_buffer_len(buffer)

            data = Data(bytes: bytes, count: length)

            signal_buffer_bzero_free(buffer)
        } else {
            fatalError()
        }

        return data
    }()

    @objc public lazy var publicKey: Data = {
        let data: Data
        let publicKeyPointer = self.keyPairPointer.pointee.public_key

        var bufferPointer: UnsafeMutablePointer<signal_buffer>? = nil
        let result = ec_public_key_serialize(&bufferPointer, publicKeyPointer)

        if result == 0, let buffer = bufferPointer, let bytes = signal_buffer_data(buffer) {
            let length = signal_buffer_len(buffer)

            data = Data(bytes: bytes, count: length)

            signal_buffer_bzero_free(buffer)
        } else {
            fatalError()
        }

        return data
    }()

    public class func publicKey(from data: Data) -> UnsafeMutablePointer<ec_public_key>? {
        var publicKeyPointer: UnsafeMutablePointer<ec_public_key>? = nil
        let bytes = (data as NSData).bytes.assumingMemoryBound(to: UInt8.self)
        let result = curve_decode_point(&publicKeyPointer, bytes, data.count, nil)

        if result < 0 {
            fatalError()
            // return nil
        }

        return publicKeyPointer
    }

    var keyPairPointer: UnsafePointer<ec_key_pair>

    public init(publicKey : UnsafeMutablePointer<ec_public_key>, privateKey: UnsafeMutablePointer<ec_private_key>) {
        var keyPairPointer: UnsafeMutablePointer<ec_key_pair>? = nil

        guard ec_key_pair_create(&keyPairPointer, publicKey, privateKey) >= 0, let keyPair = keyPairPointer else {
            fatalError()
        }

        self.keyPairPointer = UnsafePointer(keyPair)
    }

    public override init() {
        self.keyPairPointer = SignalKeyHelper.generateKeyPair()
    }

    @objc public func sign(data: Data) -> Data {
        let length = 64
        let randomData = Data.generateSecureRandomData(count: length)

        var message = [UInt8](repeating:0, count:data.count)
        data.copyBytes(to: &message, count: data.count)

        var randomBytes = [UInt8](repeating:0, count: randomData.count)
        randomData.copyBytes(to: &randomBytes, count: randomData.count)

        var signatureBuffer = [UInt8](repeating: 0, count: length)
        let privateKey = UnsafeMutablePointer<UInt8>( OpaquePointer(self.keyPairPointer.pointee.private_key) )
        guard curve25519_sign(&signatureBuffer, privateKey, message, UInt(data.count), randomBytes) >= 0 else {
            fatalError()
        }

        return Data(bytes: signatureBuffer, count: length)
    }
}
