//
//  SignalKeyPair.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 20.03.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

/// A wrapper for an EC key pair.
@objc public class SignalKeyPair: NSObject {

    /// Serialised private key. Sensitive.
    @objc public lazy var privateKey: Data = {
        let data: Data
        let privateKeyPointer = self.keyPairPointer.pointee.private_key

        var bufferPointer: UnsafeMutablePointer<signal_buffer>?
        let result = ec_private_key_serialize(&bufferPointer, privateKeyPointer)

        if result == 0, let buffer = bufferPointer, let bytes = signal_buffer_data(buffer) {
            let length = signal_buffer_len(buffer)

            data = Data(bytes: bytes, count: length)

            signal_buffer_free(buffer)
        } else {
            fatalError()
        }

        return data
    }()

    /// Serialised public key.
    @objc public lazy var publicKey: Data = {
        let data: Data
        let publicKeyPointer = self.keyPairPointer.pointee.public_key

        var bufferPointer: UnsafeMutablePointer<signal_buffer>?
        let result = ec_public_key_serialize(&bufferPointer, publicKeyPointer)

        if result == 0, let buffer = bufferPointer, let bytes = signal_buffer_data(buffer) {
            let length = signal_buffer_len(buffer)

            data = Data(bytes: bytes, count: length)

            signal_buffer_free(buffer)
        } else {
            fatalError()
        }

        return data
    }()

    /// De-serialise an ec_public_key.
    ///
    /// - Parameter data: the serialised ec_public_key data.
    /// - Returns: A pointer to the de-serialised ec_public_key.
    class func publicKey(from data: Data) -> UnsafeMutablePointer<ec_public_key>? {
        var publicKeyPointer: UnsafeMutablePointer<ec_public_key>?
        let bytes = (data as NSData).bytes.assumingMemoryBound(to: UInt8.self)
        let result = curve_decode_point(&publicKeyPointer, bytes, data.count, nil)

        if result < 0 {
            fatalError("We should never pass invalid data here.")
            // return nil
        }

        return publicKeyPointer
    }

    var keyPairPointer: UnsafeMutablePointer<ec_key_pair>

    /// Create a new SignalKeyPair from a private/public ec key pair.
    ///
    /// - Parameters:
    ///   - publicKey: the public ec key
    ///   - privateKey: the private ec key
    public init(publicKey: UnsafeMutablePointer<ec_public_key>, privateKey: UnsafeMutablePointer<ec_private_key>) {
        var keyPairPointer: UnsafeMutablePointer<ec_key_pair>?

        guard ec_key_pair_create(&keyPairPointer, publicKey, privateKey) >= 0, let keyPair = keyPairPointer else {
            fatalError()
        }

        self.keyPairPointer = keyPair
    }

    /// Generates a new signal key pair.
    ///
    /// See: SignalKeyHelper.generateKeyPair()
    public override init() {
        self.keyPairPointer = SignalKeyHelper.generateKeyPair()
    }

    deinit {
        ec_key_pair_destroy(UnsafeMutableRawPointer(mutating: self.keyPairPointer).assumingMemoryBound(to: signal_type_base.self))
    }

    /// Sign data using our private key.
    ///
    /// - Parameter data: Data to be signed.
    /// - Returns: Signed data.
    @objc public func sign(data: Data) -> Data {
        let length = 64
        let randomData = Data.generateSecureRandomData(count: length)

        var message = [UInt8](repeating: 0, count: data.count)
        data.copyBytes(to: &message, count: data.count)

        var randomBytes = [UInt8](repeating: 0, count: randomData.count)
        randomData.copyBytes(to: &randomBytes, count: randomData.count)

        var signatureBuffer = [UInt8](repeating: 0, count: length)
        let privateKey = UnsafeMutablePointer<UInt8>(OpaquePointer(self.keyPairPointer.pointee.private_key))
        guard curve25519_sign(&signatureBuffer, privateKey, message, UInt(data.count), randomBytes) >= 0 else {
            fatalError()
        }

        return Data(bytes: signatureBuffer, count: length)
    }
}
