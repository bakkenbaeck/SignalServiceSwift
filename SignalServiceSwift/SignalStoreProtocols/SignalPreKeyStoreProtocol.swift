//
//  SignalPreKeyStoreProtocol.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 20.03.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation

@objc public protocol SignalPreKeyStoreProtocol {
    func loadPreKey(with id: UInt32) -> Data?

    func storePreKey(data: Data, id: UInt32) -> Bool

    func containsPreKey(with id: UInt32) -> Bool

    func deletePreKey(with id: UInt32) -> Bool

    func nextPreKeyId() -> UInt32
}
