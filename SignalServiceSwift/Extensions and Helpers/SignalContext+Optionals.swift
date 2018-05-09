//
//  SignalContext+Optionals.swift
//  SignalServiceSwift
//
//  Created by Igor Ranieri on 20.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

// MARK: - Adding some helper methods to our SignalContext, for better swift compatibility.
extension SignalContext {
    var currentlySignedPreKeyId: UInt32? {
        // Due to how objc briding works, we cannot have this method return an optional. Instead it returns `UInt32.max`
        // if there's no valid id stored. In this case, we swiftify the value here, checking for UInt32.max, and returning nil.
        // This way we take advantage of optionals and try to encapsulate the C bridge nonsense.
        let id = self.store.signedPreKeyStore.retrieveCurrentSignedPreKeyId()

        return id == UInt32.max ? nil : id
    }

    var identityKeyPair: SignalIdentityKeyPair? {
        return self.store.identityKeyStore.identityKeyPair
    }

    func nextPreKeyId() -> UInt32 {
        let nextId = self.store.preKeyStore.nextPreKeyId()

        return nextId == UInt32.max ? 0 : nextId
    }
}
