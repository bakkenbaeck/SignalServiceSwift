//
//  SignalPreKeyBundle.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 21.03.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation

func checkValidity(of bundle: UnsafeMutablePointer<session_pre_key_bundle>) -> Bool {
    if let signed_pre_key = session_pre_key_bundle_get_signed_pre_key(bundle) {

        let identity_key = session_pre_key_bundle_get_identity_key(bundle)
        let signature = session_pre_key_bundle_get_signed_pre_key_signature(bundle)
        var serialized_signed_pre_key: UnsafeMutablePointer<signal_buffer>?

        guard ec_public_key_serialize(&serialized_signed_pre_key, signed_pre_key) == 0 else {
            return false
        }

        guard curve_verify_signature(identity_key,
                                     signal_buffer_data(serialized_signed_pre_key),
                                     signal_buffer_len(serialized_signed_pre_key),
                                     signal_buffer_data(signature),
                                     signal_buffer_len(signature)) > 0
            else {
                return false
        }

        signal_buffer_free(serialized_signed_pre_key)
    }

    return true
}

public class SignalPreKeyBundle: NSObject {
    public private(set) var registrationId: UInt32
    private(set) var deviceId: Int32
    private(set) var preKeyId: UInt32
    private(set) var preKeyPublic: Data
    private(set) var signedPreKeyId: UInt32
    private(set) var signedPreKeyPublic: Data
    private(set) var signature: NSData
    private(set) var identityKey: Data

    private(set) var bundle: UnsafeMutablePointer<session_pre_key_bundle>

    public init?(registrationId: UInt32, deviceId: Int32, preKeyId: UInt32, preKeyPublic: Data, signedPreKeyId: UInt32, signedPreKeyPublic
        : Data, signature: NSData, identityKey: Data) {

        self.registrationId = registrationId;
        self.deviceId = deviceId
        self.preKeyId = preKeyId
        self.preKeyPublic = preKeyPublic
        self.signedPreKeyId = signedPreKeyId
        self.signedPreKeyPublic = signedPreKeyPublic
        self.signature = signature
        self.identityKey = identityKey

        guard let pre_key_public = SignalKeyPair.publicKey(from: preKeyPublic),
            let signed_pre_key_public = SignalKeyPair.publicKey(from: signedPreKeyPublic),
            let identity_key = SignalKeyPair.publicKey(from: identityKey) else {
                return nil
        }

        let signatureBytes = signature.bytes.assumingMemoryBound(to: UInt8.self)
        let signatureLength = signature.length
        var bundlePointer: UnsafeMutablePointer<session_pre_key_bundle>? = nil

        guard session_pre_key_bundle_create(&bundlePointer,
                                            registrationId,
                                            deviceId,
                                            preKeyId,
                                            pre_key_public,
                                            signedPreKeyId,
                                            signed_pre_key_public,
                                            signatureBytes,
                                            signatureLength,
                                            identity_key) >= 0,
            let bundle = bundlePointer,
            checkValidity(of: bundle) else {
                return nil
        }

        self.bundle = bundle
    }

    public convenience init?(_ dict: Dictionary<String, Any>) {
        guard let identityKey = dict["identityKey"] as? String,
            let devicesAry = dict["devices"] as? [[String: Any]],
            let devices = devicesAry.first,

            let registrationId = devices["registrationId"] as? UInt32,

            let signedPreKey = devices["signedPreKey"] as? [String: Any],
            let signedPreKeyId = signedPreKey["keyId"] as? UInt32,
            let signedPreKeyPublicKey = signedPreKey["publicKey"] as? String,
            let signedPreKeySignature = signedPreKey["signature"] as? String,

            let deviceId = devices["deviceId"] as? Int32,

            let preKey = devices["preKey"] as? [String: Any],
            let preKeyId = preKey["keyId"] as? UInt32,
            let preKeyPublicKey = preKey["publicKey"] as? String,

            let preKeyPublicKeyData = Data(base64EncodedWithoutPadding: preKeyPublicKey),
            let signedPreKeyPublicKeyData = Data(base64EncodedWithoutPadding: signedPreKeyPublicKey),
            let signatureData = Data(base64EncodedWithoutPadding: signedPreKeySignature) as NSData?,
            let identityKeyData = Data(base64EncodedWithoutPadding: identityKey)
            else {
                return nil
        }

        self.init(registrationId: registrationId, deviceId: deviceId, preKeyId: preKeyId, preKeyPublic: preKeyPublicKeyData, signedPreKeyId: signedPreKeyId, signedPreKeyPublic: signedPreKeyPublicKeyData, signature: signatureData, identityKey: identityKeyData)
    }
}
