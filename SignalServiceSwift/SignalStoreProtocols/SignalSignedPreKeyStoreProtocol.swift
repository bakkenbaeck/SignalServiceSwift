//
//  SignalSignedPreKeyStoreProtocol.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 20.03.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation

@objc public protocol SignalSignedPreKeyStoreProtocol {

    /// Load a local serialized signed PreKey record.
    ///
    /// - Parameter signedPreKeyId: ID of SignedPreKey
    /// - Returns: Return nil if no key for given id. Returns key as Data? if it exists.
    func loadSignedPreKey(withId signedPreKeyId: UInt32) -> Data?


    /// Store a local serialized signed PreKey record.
    ///
    /// - Parameters:
    ///   - signedPreKey: SignedPreKey as Data
    ///   - signedPreKeyId: SignedPreKey ID
    /// - Returns: True if successfully stored.
    @discardableResult func storeSignedPreKey(_ signedPreKey: Data?, signedPreKeyId: UInt32) -> Bool


    /// Determine whether there is a committed signed PreKey record matching the provided ID.
    ///
    /// - Parameter signedPreKeyId: ID of signed PreKey to check.
    /// - Returns: True if Store contains the given signed pre key.
    func containsSignedPreKey(withId signedPreKeyId: UInt32) -> Bool


    /// Delete a SignedPreKeyRecord from local storage.
    ///
    /// - Parameter signedPreKeyId: Id of the signed PreKey to delete.
    /// - Returns: True if successful, false if it failed.
    func removeSignedPreKey(withId signedPreKeyId: UInt32) -> Bool


    /// Fetch the ID of the current signed pre key.
    ///
    /// Use this to check whether we need to update the signed pre key.
    /// If id is MAX_UINT32, we should update it!
    ///
    /// - Returns: The ID of the current signed pre key.
    func fetchCurrentSignedPreKeyId() -> UInt32

    /// Store the ID of the current signed pre key.
    ///
    /// Use this to store the currently signed pre key. Should be updated every time we update the signed pre key.
    ///
    /// - Parameter id: id of the currently signed pre key.
    /// - Returns: true if successfully stored.
    @discardableResult func storeCurrentSignedPreKeyId(_ id: UInt32) -> Bool
}
