//
//  SignalSessionBuilder.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 21.03.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation

public class SignalSessionBuilder: NSObject {
    public let address: SignalAddress
    public let context: SignalContext

    public let builder: UnsafeMutablePointer<session_builder>

    public init?(address: SignalAddress, context: SignalContext) {
        self.address = address
        self.context = context

        let remote_address = UnsafeMutablePointer<signal_protocol_address>.allocate(capacity: 1)
        remote_address.initialize(from: &address.address, count: 1)

        let builderPointer = UnsafeMutablePointer<session_builder>.allocate(capacity: 1)
        builderPointer.pointee.global_context = context.context
        builderPointer.pointee.remote_address = UnsafePointer<signal_protocol_address>(remote_address)
        builderPointer.pointee.store = context.store.storeContextPointer

        self.builder = builderPointer
    }

    deinit {
        session_builder_free(self.builder)
    }

    public func processPreKeyBundle(_ preKeyBundle: SignalPreKeyBundle) -> Bool {
        let result = session_builder_process_pre_key_bundle(self.builder, preKeyBundle.bundle)

        return result >= 0
    }
}
