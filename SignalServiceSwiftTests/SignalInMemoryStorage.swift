//
//  SignalInMemoryStorage.swift
//  SignalWrapperTests
//
//  Created by Igor Ranieri on 22.03.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation
import SignalServiceSwift

@objc public class SignalStoreInMemoryStorage: NSObject, SignalStoreProtocol {
    @objc public var identityKeyPair: SignalIdentityKeyPair!
    @objc public var localRegistrationId: UInt32 = 0

    private(set) var sessionStore = NSMutableDictionary()
    private(set) var preKeyStore = NSMutableDictionary()
    private(set) var signedPreKeyStore = NSMutableDictionary()
    private(set) var identityKeyStore = NSMutableDictionary()
    private(set) var senderKeyStore = NSMutableDictionary()

    private let currentlySignedPreKeyStoreKey = "CurrentlySignedPreKey"

    // MARK: SignalSessionStore
    @objc public func deviceSessionRecords(forAddressName addressName: String) -> NSMutableDictionary? {
        guard let copy = (self.sessionStore.value(forKey: addressName) as? NSDictionary) else {
            return nil
        }

        return NSMutableDictionary(dictionary: copy)
    }

    /**
     * Returns a copy of the serialized session record corresponding to the
     * provided recipient ID + device ID tuple.
     * or nil if not found.
     */
    @objc public func sessionRecord(for address: SignalAddress) -> Data? {
        return (self.deviceSessionRecords(forAddressName: address.name) ?? [:])[address.deviceId] as? Data
    }

    /**
     * Commit to storage the session record for a given
     * recipient ID + device ID tuple.
     *
     * Return YES on success, NO on failure.
     */
    @objc public func storeSessionRecord(_ recordData: Data, for address: SignalAddress) -> Bool {
        let dict = [address.deviceId: recordData]
        self.sessionStore[address.name] = dict

        return self.sessionRecordExists(for: address)
    }

    /**
     * Determine whether there is a committed session record for a
     * recipient ID + device ID tuple.
     */
    @objc public func sessionRecordExists(for address: SignalAddress) -> Bool {
        return self.sessionStore[address.name] != nil
    }

    /**
     * Remove a session record for a recipient ID + device ID tuple.
     */
    @objc public func deleteSessionRecord(for address: SignalAddress) -> Bool {
        self.deviceSessionRecords(forAddressName: address.name)?.removeObject(forKey: address.deviceId)

        return true
    }

    /**
     * Remove the session records corresponding to all devices of a recipient ID.
     *
     * @return the number of deleted sessions on success, negative on failure
     */
    @objc public func deleteAllSessions(for addressName: String) -> Int32 {
        if let deviceSessionRecords = self.deviceSessionRecords(forAddressName: addressName) {
            let count = deviceSessionRecords.count
            deviceSessionRecords.removeAllObjects()

            return Int32(count)
        }

        return 0
    }


    // MARK: SignalPreKeyStore
    /**
     * Load a local serialized PreKey record.
     * return nil if not found
     */
    @objc public func loadPreKey(with id: UInt32) -> Data? {
        return self.preKeyStore.object(forKey: id) as? Data
    }

    /**
     * Store a local serialized PreKey record.
     * return YES if storage successful, else NO
     */
    @discardableResult @objc public func storePreKey(data: Data, id: UInt32) -> Bool {
        self.preKeyStore[id] = data

        return true
    }

    /**
     * Determine whether there is a committed PreKey record matching the
     * provided ID.
     */
    @objc public func containsPreKey(with id: UInt32) -> Bool {
        return self.preKeyStore[id] != nil
    }

    /**
     * Delete a PreKey record from local storage.
     */
    @discardableResult
    @objc public func deletePreKey(with id: UInt32) -> Bool {
        self.preKeyStore.removeObject(forKey: id)

        return self.preKeyStore[id] == nil
    }

    public func nextPreKeyId() -> UInt32 {
        let allKeys = (self.preKeyStore.allKeys as! [UInt32]).sorted()

        return allKeys.last! + 1
    }


    // MARK: SignalSignedPreKeyStore
    /**
     * Load a local serialized signed PreKey record.
     */
    @objc public func loadSignedPreKey(withId signedPreKeyId: UInt32) -> Data? {
        return self.signedPreKeyStore[signedPreKeyId] as? Data
    }

    /**
     * Store a local serialized signed PreKey record.
     */
    @discardableResult
    @objc public func storeSignedPreKey(_ signedPreKey: Data?, signedPreKeyId: UInt32) -> Bool {
        self.signedPreKeyStore[signedPreKeyId] = signedPreKey

        return true
    }

    /**
     * Determine whether there is a committed signed PreKey record matching
     * the provided ID.
     */
    @objc public func containsSignedPreKey(withId signedPreKeyId: UInt32) -> Bool {
        return self.signedPreKeyStore[signedPreKeyId] != nil
    }

    /**
     * Delete a SignedPreKeyRecord from local storage.
     */
    @discardableResult
    @objc public func removeSignedPreKey(withId signedPreKeyId: UInt32) -> Bool {
        self.signedPreKeyStore.removeObject(forKey: signedPreKeyId)

        return true
    }

    public func fetchCurrentSignedPreKeyId() -> UInt32 {
        return (self.signedPreKeyStore[self.currentlySignedPreKeyStoreKey] as? UInt32) ?? UInt32.max
    }

    public func storeCurrentSignedPreKeyId(_ id: UInt32) -> Bool {
        self.signedPreKeyStore[self.currentlySignedPreKeyStoreKey] = id

        return (self.signedPreKeyStore[self.currentlySignedPreKeyStoreKey] as? UInt32 != nil)
    }

    /**
     * Save a remote client's identity key
     * <p>
     * Store a remote client's identity key as trusted.
     * The value of key_data may be null. In this case remove the key data
     * from the identity store, but retain any metadata that may be kept
     * alongside it.
     */
    @objc public func saveIdentity(with address: SignalAddress, identityKey: Data?) -> Bool {
        self.identityKeyStore[address.name] = identityKey

        return self.identityKeyStore[address.name] != nil
    }

    /**
     * Verify a remote client's identity key.
     *
     * Determine whether a remote client's identity is trusted.  Convention is
     * that the TextSecure protocol is 'trust on first use.'  This means that
     * an identity key is considered 'trusted' if there is no entry for the recipient
     * in the local store, or if it matches the saved key for a recipient in the local
     * store.  Only if it mismatches an entry in the local store is it considered
     * 'untrusted.'
     */
    @objc public func isTrustedIdentity(with address: SignalAddress, identityKey: Data) -> Bool {
        guard let existingKey = self.identityKeyStore[address.name] as? Data else {
            return true
        }

        if existingKey == identityKey {
            return true
        }

        return false
    }

    // MARK: SignalSenderKeyStore
    func key(for address: SignalAddress, groupId: String) -> String? {
        return "\(address.name)\(address.deviceId)\(groupId)"
    }

    /**
     * Store a serialized sender key record for a given
     * (groupId + senderId + deviceId) tuple.
     */
    @objc public func storeSenderKey(with data: Data, signalAddress: SignalAddress, groupId: String) -> Bool {
        if let key = self.key(for: signalAddress, groupId: groupId) {
            self.senderKeyStore[key] = data
        }

        return true
    }

    /**
     * Returns a copy of the sender key record corresponding to the
     * (groupId + senderId + deviceId) tuple.
     */
    @objc public func loadSenderKey(for address: SignalAddress, groupId: String) -> Data? {
        if let key = self.key(for: address, groupId: groupId) {
            return self.senderKeyStore[key] as? Data
        }

        return nil
    }

    @objc public func allDeviceIds(for addressName: String) -> [NSNumber] {
        return self.deviceSessionRecords(forAddressName: addressName)?.allKeys as? [NSNumber] ?? []
    }
}
