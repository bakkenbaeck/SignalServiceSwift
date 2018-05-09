//
//  SignalSignedPreKeyStoreProtocol.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 20.03.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

/// Stores and retrieves ours and our contacts' signed prekeys.
@objc public protocol SignalSignedPreKeyStoreProtocol {

    /// Load a local serialised signed PreKey record.
    ///
    /// - Parameter signedPreKeyId: ID of SignedPreKey
    /// - Returns: Return nil if no key for given id. Returns key as Data? if it exists.
    func loadSignedPreKey(with signedPreKeyId: UInt32) -> Data?

    /// Store a local serialised signed PreKey record.
    ///
    /// - Parameters:
    ///   - signedPreKey: SignedPreKey as Data
    ///   - signedPreKeyId: SignedPreKey ID
    /// - Returns: True if successfully stored.
    @discardableResult func storeSignedPreKey(_ signedPreKey: Data?, signedPreKeyId: UInt32) -> Bool

    /// Determine whether there is a committed signed PreKey record matching the provided ID.
    ///
    /// - Parameter signedPreKeyId: ID of signed PreKey to check.
    /// - Returns: True if Store contains the given signed prekey.
    func containsSignedPreKey(with signedPreKeyId: UInt32) -> Bool

    /// Delete a SignedPreKeyRecord from local storage.
    ///
    /// - Parameter signedPreKeyId: Id of the signed PreKey to delete.
    /// - Returns: True if successful, false if it failed.
    func removeSignedPreKey(with signedPreKeyId: UInt32) -> Bool

    /// Fetch the ID of the current signed prekey.
    ///
    /// Use this to check whether we need to update the signed prekey.
    /// If id is MAX_UINT32, we should update it!
    ///
    /// - Returns: The ID of the current signed prekey.
    func retrieveCurrentSignedPreKeyId() -> UInt32

    /// Store the ID of the current signed prekey.
    ///
    /// Use this to store the currently signed prekey. Should be updated every time we update the signed prekey.
    ///
    /// - Parameter id: id of the currently signed prekey.
    /// - Returns: true if successfully stored.
    @discardableResult func storeCurrentSignedPreKeyId(_ id: UInt32) -> Bool
}
