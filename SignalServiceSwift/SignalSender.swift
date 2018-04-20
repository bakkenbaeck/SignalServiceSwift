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
//    let signalKeyHelper: SignalKeyHelper
//    let signalContext: SignalContext
//
//
//    var identityKeyPair: SignalIdentityKeyPair {
//        return self.signalContext.store.identityKeyStore.identityKeyPair
//    }
//
//    func nextPreKeyId() -> UInt32? {
//        let nextId = self.signalContext.store.preKeyStore.nextPreKeyId()
//
//        return nextId == UInt32.max ? nil : nextId
//    }
}
