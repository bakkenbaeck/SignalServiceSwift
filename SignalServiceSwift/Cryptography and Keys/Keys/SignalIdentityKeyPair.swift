//
//  SignalIdentityKeyPair.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 20.03.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

/// Our ratchet identity key pair. Used to validate that we are who we say we are with the signal server.
///
/// Should be stored locally and kept safe.
@objc public class SignalIdentityKeyPair: SignalKeyPair {
    let identityKeyPairPointer: UnsafeMutablePointer<ratchet_identity_key_pair>

    lazy var serialized: Data = {
        var buffer: UnsafeMutablePointer<signal_buffer>?
        _ = ratchet_identity_key_pair_serialize(&buffer, self.identityKeyPairPointer)

        let data = Data(bytes: signal_buffer_data(buffer), count: signal_buffer_len(buffer))

        signal_buffer_free(buffer)

        return data
    }()

    public init(identityKeyPair: UnsafeMutablePointer<ratchet_identity_key_pair>) {
        self.identityKeyPairPointer = identityKeyPair

        guard let privateKey = ratchet_identity_key_pair_get_private(identityKeyPair),
            let publicKey = ratchet_identity_key_pair_get_public(identityKeyPair) else {
            fatalError()
        }

        super.init(publicKey: publicKey, privateKey: privateKey)
    }

    deinit {
        ratchet_identity_key_pair_destroy(UnsafeMutableRawPointer(identityKeyPairPointer).assumingMemoryBound(to: signal_type_base.self))
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
