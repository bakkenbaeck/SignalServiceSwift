//
//  SignalKeyHelper.m
//  SignalWrapper
//
//  Created by Igor Ranieri on 21.03.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

/// Our key helper, responsible for generating random data, private keys, signed prekeys and identity key pairs.
@objc public class SignalKeyHelper: NSObject {
    public private(set) var context: SignalContext

    @objc public init(context: SignalContext) {
        self.context = context

        super.init()
    }

    /// Generates a new identity key pairs.
    ///
    /// - Important: As a side-effect, it will automatically replaced our stored identity key. Use with care.
    ///
    /// - Returns: Our new signal identity key pair.
    public func generateAndStoreIdentityKeyPair() -> SignalIdentityKeyPair? {
        var keyPairPointer: UnsafeMutablePointer<ratchet_identity_key_pair>?
        let result = signal_protocol_key_helper_generate_identity_key_pair(&keyPairPointer, self.context.context)

        guard let keyPair = keyPairPointer, result >= 0 else {
            return nil
        }

        let identityKey = SignalIdentityKeyPair(identityKeyPair: keyPair)

        guard self.context.store.identityKeyStore.saveIdentity(identityKey.serialized) else { fatalError("Could not store new identity key") }

        return identityKey
    }

    /// Generates our registration id.
    ///
    /// - Returns: Our newly generated registration id, to be sent to the chat server.
    public func generateRegistrationId() -> UInt32 {
        var registration_id: UInt32 = 0
        let result = signal_protocol_key_helper_generate_registration_id(&registration_id, 1, self.context.context)

        if result < 0 {
            return 0
        }

        return registration_id
    }

    /// Generates our pre-keys. prekeys are used so that other users can send us messages before we've exchanged a shared secret.
    ///
    /// - Parameters:
    ///   - startingPreKeyId: The id of our last generated prekey + 1, or 0. See: SignalPreKeyStore's `nextPreKeyId()`
    ///   - count: How many pre-keys we want to generate. Signal recommends 100.
    /// - Returns: An array of our newly generated prekeys. Not yet locally stored.
    @objc public func generatePreKeys(withStartingPreKeyId startingPreKeyId: UInt32, count: UInt32) -> [SignalPreKey] {
        var headPointer: UnsafeMutablePointer<signal_protocol_key_helper_pre_key_list_node>?
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

        signal_protocol_key_helper_key_list_free(headPointer)

        return keys
    }

    /// Generate our signed prekey.
    ///
    /// - Parameters:
    ///   - identityKeyPair: our valid and current identity key pair.
    ///   - signedPreKeyId: the id ouf our generated signed prekey. Do not user UInt32.max. Ideally a random number.
    ///
    /// - Returns: Our newly generated signed prekey. Not yet locally stored.
    public func generateSignedPreKey(withIdentity identityKeyPair: SignalIdentityKeyPair, signedPreKeyId: UInt32) -> SignalSignedPreKey {
        var signedPreKeyPointer: UnsafeMutablePointer<session_signed_pre_key>?
        let unixTimestamp = Date().milisecondTimeIntervalSinceEpoch

        let result = signal_protocol_key_helper_generate_signed_pre_key(&signedPreKeyPointer, identityKeyPair.identityKeyPairPointer, signedPreKeyId, unixTimestamp, self.context.context)

        guard result >= 0, let signedPreKey = signedPreKeyPointer else {
            fatalError()
        }

        let signalSignedPreKey = SignalSignedPreKey(with: signedPreKey)

        return signalSignedPreKey
    }

    /// Generates a new key pair, using elitpical curve cryptography.
    ///
    /// - Returns: A newly generated EC key pair. Not yet locally stored.
    public static func generateKeyPair() -> UnsafeMutablePointer<ec_key_pair> {
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

        var keyPairPointer: UnsafeMutablePointer<ec_key_pair>?
        let publicKeyPointer = UnsafeMutablePointer<ec_public_key>(OpaquePointer(publicKey))
        let privateKeyPointer = UnsafeMutablePointer<ec_private_key>(OpaquePointer(privateKey))

        guard ec_key_pair_create(&keyPairPointer, publicKeyPointer, privateKeyPointer) == 0, let keyPair = keyPairPointer else {
            fatalError()
        }

        return keyPair
    }
}
