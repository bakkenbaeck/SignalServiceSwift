//
//  SignalIdentityKeyStoreProtocol.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 20.03.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

/// Handles storing and retrieving the identity keys (our own as well as the remote id keys for our contacts).
@objc public protocol SignalIdentityKeyStoreProtocol {
    /**
     * Get the local client's identity key pair.
     */
    var identityKeyPair: SignalIdentityKeyPair? { get }

    /**
     * Return the local client's registration ID.
     *
     * Clients should maintain a registration ID, a random number
     * between 1 and 16380 that's generated once at install time.
     *
     * return negative on failure
     */
    var localRegistrationId: UInt32 { get set }

    /**
     * Save a remote client's identity key
     *
     * Store a remote client's identity key as trusted.
     * The value of key_data may be null. In this case remove the key data
     * from the identity store, but retain any metadata that may be kept
     * alongside it.
     */
    func saveRemoteIdentity(with address: SignalAddress, identityKey: Data?) -> Bool

    /**
     Save the identity key for the current user.
     */
    func saveIdentity(_ identityKey: Data?) -> Bool

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
    func isTrustedIdentity(with address: SignalAddress, identityKey: Data) -> Bool
}
