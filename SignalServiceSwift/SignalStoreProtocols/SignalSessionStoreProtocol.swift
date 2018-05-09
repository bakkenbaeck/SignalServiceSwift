//
//  SignalSessionStoreProtocol.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 20.03.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

/// Store and retrieve our chat sessions.
///
/// A session record is responsble for storing and managing our encryption and decryption keys.
@objc public protocol SignalSessionStoreProtocol: class {
    /**
     * Returns a copy of the serialised session record corresponding to the
     * provided recipient ID + device ID tuple.
     * or nil if not found.
     */
    func sessionRecord(for address: SignalAddress) -> Data

    /**
     * Commit to storage the session record for a given
     * recipient ID + device ID tuple.
     *
     * Return YES on success, NO on failure.
     */
    func storeSessionRecord(_ recordData: Data, for address: SignalAddress) -> Bool

    /**
     * Determine whether there is a committed session record for a
     * recipient ID + device ID tuple.
     */
    func sessionRecordExists(for address: SignalAddress) -> Bool

    /**
     * Remove a session record for a recipient ID + device ID tuple.
     */
    func deleteSessionRecord(for address: SignalAddress) -> Bool

    /// Retrieves the device ids for a given recipient.
    ///
    /// - Returns: all known devices with active sessions for a recipient
    func allDeviceIds(for addressName: String) -> [Int32]

    /// Remove the session records corresponding to all devices of a recipient ID.
    ///
    /// - Returns: he number of deleted sessions on success, negative on failure
    func deleteAllDeviceSessions(for addressName: String) -> Int32
}
