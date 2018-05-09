//
//  UserBootstrapParams.swift
//  Demo
//
//  Created by Igor Ranieri on 16.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation
import SignalServiceSwift

/// Prepares user keys and data, signs and formats it properly as JSON to bootstrap a chat user.
class UserBootstrapParameter {
    let password: String

    let identityKey: String

    let identityKeyPair: SignalIdentityKeyPair

    let prekeys: [SignalPreKey]

    let registrationId: UInt32

    let signalingKey: String

    let signedPrekey: SignalSignedPreKey

    lazy var payload: [String: Any] = {
        var prekeys = [[String: Any]]()

        for prekey in self.prekeys {
            let prekeyParam: [String: Any] = [
                "keyId": prekey.preKeyId,
                "publicKey": prekey.keyPair.publicKey.base64EncodedString()
            ]
            prekeys.append(prekeyParam)
        }

        let signedPreKey: [String: Any] = [
            "keyId": Int(self.signedPrekey.preKeyId),
            "publicKey": self.signedPrekey.keyPair.publicKey.base64EncodedString(),
            "signature": self.signedPrekey.signature.base64EncodedString()
        ]

        let payload: [String: Any] = [
            "identityKey": self.identityKey,
            "password": self.password,
            "preKeys": prekeys,
            "registrationId": Int(self.registrationId),
            "signalingKey": self.signalingKey,
            "signedPreKey": signedPreKey
        ]

        return payload
    }()

    init(user: User, signalClient: SignalClient) {
        self.identityKeyPair = signalClient.signalContext.signalKeyHelper.generateIdentityKeyPair()!
        self.password = user.password

        self.identityKey = self.identityKeyPair.publicKey.base64EncodedString()
        self.prekeys = signalClient.signalContext.signalKeyHelper.generatePreKeys(withStartingPreKeyId: 1, count: 100)
        self.registrationId = signalClient.signalContext.signalKeyHelper.generateRegistrationId()
        self.signalingKey = Data.generateSecureRandomData(count: 52).base64EncodedString()
        self.signedPrekey = signalClient.signalContext.signalKeyHelper.generateSignedPreKey(withIdentity: self.identityKeyPair, signedPreKeyId: 0)

        for prekey in self.prekeys {
            _ = signalClient.libraryStore.storePreKey(data: prekey.serializedData, id: prekey.preKeyId)
        }

        signalClient.libraryStore.storeSignedPreKey(self.signedPrekey.serializedData, signedPreKeyId: self.signedPrekey.preKeyId)
        signalClient.libraryStore.storeCurrentSignedPreKeyId(self.signedPrekey.preKeyId)
    }
}
