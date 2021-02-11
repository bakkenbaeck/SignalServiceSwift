//
//  SignalLibraryStoreProtocol.swift
//  SignalServiceSwift
//
//  Created by Igor Ranieri on 25.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation

// Catch-all protocol that incorporates all individual store types.
public protocol SignalLibraryStoreProtocol: SignalSessionStoreProtocol, SignalPreKeyStoreProtocol, SignalSignedPreKeyStoreProtocol, SignalIdentityKeyStoreProtocol, SignalSenderKeyStoreProtocol {

    var delegate: SignalLibraryStoreDelegate { get }

    var context: SignalContext! { get set }
}
