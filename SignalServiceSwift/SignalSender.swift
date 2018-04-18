//
//  SignalSender.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 09.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation

struct SignalSender {
    var username: String
    var password: String
    var deviceId: Int32
    var remoteRegistrationId: UInt32
    let signalingKey: String
    let signalKeyHelper: SignalKeyHelper
    let signalContext: SignalContext

    var currentlySignedPreKeyId: UInt32? {
        // Due to how objc briding works, we cannot have this method return an optional. Instead it returns `UInt32.max`
        // if there's no valid id stored. In this case, we swiftify the value here, checking for UInt32.max, and returning nil.
        // This way we take advantage of optionals and try to encapsulate the C bridge nonsense.
        let id = self.signalContext.store.signedPreKeyStore.fetchCurrentSignedPreKeyId()

        return id == UInt32.max ? nil : id
    }

    var identityKeyPair: SignalIdentityKeyPair {
        return self.signalContext.store.identityKeyStore.identityKeyPair
    }

    func nextPreKeyId() -> UInt32? {
        let nextId = self.signalContext.store.preKeyStore.nextPreKeyId()

        return nextId == UInt32.max ? nil : nextId
    }
}
