//
//  SignalSenderKeyStoreProtocol.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 20.03.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation

@objc public protocol SignalSenderKeyStoreProtocol {
    /**
     * Store a serialized sender key record for a given
     * (groupId + senderId + deviceId) tuple.
     */
    @objc func storeSenderKey(with data: Data, signalAddress: SignalAddress, groupId: String)-> Bool

    /**
     * Returns a copy of the sender key record corresponding to the
     * (groupId + senderId + deviceId) tuple.
     */
    @objc func loadSenderKey(for address: SignalAddress, groupId: String) -> Data?
}
