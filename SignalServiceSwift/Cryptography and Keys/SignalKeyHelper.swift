//
//  SignalKeyHelper.m
//  SignalWrapper
//
//  Created by Igor Ranieri on 21.03.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation

public class SignalKeyHelper {
    public private(set) var context: SignalContext
    
    public init(context: SignalContext) {
        self.context = context
    }

    public func generateIdentityKeyPair() -> SignalIdentityKeyPair? {
        var keyPairPointer: UnsafeMutablePointer<ratchet_identity_key_pair>? = nil
        let result = signal_protocol_key_helper_generate_identity_key_pair(&keyPairPointer, self.context.context)

        guard let keyPair = keyPairPointer, result >= 0 else {
            return nil
        }

        let identityKey = SignalIdentityKeyPair(identityKeyPair: keyPair)

        return identityKey
    }

    public func generateRegistrationId() -> UInt32 {
        var registration_id: UInt32 = 0
        let result = signal_protocol_key_helper_generate_registration_id(&registration_id, 1, self.context.context)

        if result < 0 {
            return 0
        }

        return registration_id
    }

    public func generatePreKeys(withStartingPreKeyId startingPreKeyId: UInt32, count: UInt32) -> [SignalPreKey] {
        var headPointer: UnsafeMutablePointer<signal_protocol_key_helper_pre_key_list_node>? = nil
        let result = signal_protocol_key_helper_generate_pre_keys(&headPointer, startingPreKeyId, count, self.context.context)

        guard result >= 0, headPointer != nil else {
            return []
        }

        var keys = [SignalPreKey]()

        while headPointer != nil {
            let preKeyPointer: UnsafeMutablePointer<session_pre_key> = signal_protocol_key_helper_key_list_element(headPointer)
            let preKey = SignalPreKey(withPreKey: preKeyPointer)
            keys.append(preKey)

            headPointer = signal_protocol_key_helper_key_list_next(headPointer)
        }

        return keys
    }

    public func generateSignedPreKey(withIdentity identityKeyPair: SignalIdentityKeyPair, signedPreKeyId: UInt32, timestamp: Date) -> SignalSignedPreKey {
        var signedPreKeyPointer: UnsafeMutablePointer<session_signed_pre_key>? = nil
        let unixTimestamp = UInt64(timestamp.timeIntervalSince1970 * 1000)

        let result = signal_protocol_key_helper_generate_signed_pre_key(&signedPreKeyPointer, identityKeyPair.identityKeyPairPointer, signedPreKeyId, unixTimestamp, self.context.context)

        guard result >= 0, let signedPreKey = signedPreKeyPointer else {
            fatalError()
        }

        let signalSignedPreKey = SignalSignedPreKey(with: signedPreKey)

        return signalSignedPreKey
    }

    public func generateSignedPreKey(withIdentity identityKeyPair: SignalIdentityKeyPair, signedPreKeyId: UInt32) -> SignalSignedPreKey {
        return self.generateSignedPreKey(withIdentity: identityKeyPair, signedPreKeyId: signedPreKeyId, timestamp: Date())
    }

    public static func generateKeyPair() -> UnsafePointer<ec_key_pair> {
        let length = 32
        var privateKey = [UInt8](repeating: 0, count: length)
        var publicKey = [UInt8](repeating: 0, count: length)

        var randomData = Data.generateSecureRandomData(count: length)
        memcpy(&privateKey, &randomData, length)

        privateKey[0] &= 248
        privateKey[31] &= 127
        privateKey[31] |= 64

        var basepoint = [UInt8](repeating: 0, count: length)
        basepoint[0] = 9

        curve25519_donna(&publicKey, &privateKey, &basepoint)

        var keyPairPointer: UnsafeMutablePointer<ec_key_pair>? = nil
        let publicKeyPointer = UnsafeMutablePointer<ec_public_key>(OpaquePointer(publicKey))
        let privateKeyPointer = UnsafeMutablePointer<ec_private_key>(OpaquePointer(privateKey))

        guard ec_key_pair_create(&keyPairPointer, publicKeyPointer, privateKeyPointer) == 0, let keyPair = keyPairPointer else {
            fatalError()
        }

        return UnsafePointer(keyPair)
    }

}
