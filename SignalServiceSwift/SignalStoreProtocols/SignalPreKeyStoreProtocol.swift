//
//  SignalPreKeyStoreProtocol.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 20.03.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

/// Store and retrieve ours and our contacts' unsigned prekeys.
@objc public protocol SignalPreKeyStoreProtocol {

    /// Load a serialised PreKey record.
    ///
    /// - Parameter id: ID of SignedPreKey
    /// - Returns: Return nil if no key for given id. Returns key as Data? if it exists.
    func loadPreKey(with id: UInt32) -> Data?

    /// Store a local serialised PreKey record.
    ///
    /// - Parameters:
    ///   - data: serialised prekey
    ///   - id: prekey ID
    /// - Returns: True if successfully stored.
    func storePreKey(data: Data, id: UInt32) -> Bool

    /// Determine whether there is a committed PreKey record matching the provided ID.
    ///
    /// - Parameter id: ID of PreKey to check.
    /// - Returns: True if the Store contains the given prekey record.
    func containsPreKey(with id: UInt32) -> Bool

    /// Delete a PreKey from storage.
    ///
    /// - Parameter id: Id of the PreKey to delete.
    /// - Returns: True if successful, false if failed.
    func deletePreKey(with id: UInt32) -> Bool

    /// Calculates the id of our next prekey.
    ///
    /// - Returns: A UInt32 value that is the id of our last generated pre-key plus one.
    func nextPreKeyId() -> UInt32
}
