//
//  SignalIdentityKeyPair.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 20.03.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation

@objc public class SignalIdentityKeyPair: SignalKeyPair {
    @objc public var identityKeyPairPointer: UnsafeMutablePointer<ratchet_identity_key_pair>

    public init(identityKeyPair: UnsafeMutablePointer<ratchet_identity_key_pair>) {
        self.identityKeyPairPointer = identityKeyPair

        guard let privateKey = ratchet_identity_key_pair_get_private(identityKeyPair),
            let publicKey = ratchet_identity_key_pair_get_public(identityKeyPair) else {
                fatalError()
        }

        super.init(publicKey: publicKey, privateKey: privateKey)
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
