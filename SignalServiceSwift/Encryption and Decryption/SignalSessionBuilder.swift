//
//  SignalSessionBuilder.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 21.03.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

/// Builds a session and processes a prekey bundle, so that we can send messages to a given SignalAddress.
class SignalSessionBuilder: NSObject {
    let address: SignalAddress
    let context: SignalContext

    init(address: SignalAddress, context: SignalContext) {
        self.address = address
        self.context = context
    }

    func processPreKeyBundle(_ preKeyBundle: SignalPreKeyBundle) -> Bool {
        var builderPointer: UnsafeMutablePointer<session_builder>?
        guard session_builder_create(&builderPointer, self.context.store.storeContextPointer, self.address.addressPointer, self.context.context) >= 0, let builder = builderPointer else {
            fatalError()
        }

        defer {
            session_builder_free(builder)
        }

        guard session_builder_process_pre_key_bundle(builder, preKeyBundle.bundle) >= 0 else {
            return false
        }

        return true
    }
}
