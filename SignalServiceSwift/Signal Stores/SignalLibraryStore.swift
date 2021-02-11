//
//  SignalLibraryStore.swift
//  SignalServiceSwift
//
//  Created by Igor Ranieri on 19.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

public protocol SignalLibraryStoreDelegate: class {
    func storeSignalLibraryValue(_ value: Data, key: String, type: SignalLibraryStore.LibraryStoreType)

    func deleteSignalLibraryValue(key: String, type: SignalLibraryStore.LibraryStoreType) -> Bool

    func retrieveSignalLibraryValue(key: String, type: SignalLibraryStore.LibraryStoreType) -> Data?

    func retrieveAllSignalLibraryValue(ofType type: SignalLibraryStore.LibraryStoreType) -> [Data]
}

public class SignalLibraryStore: NSObject, SignalLibraryStoreProtocol {
    private let IdentityKeyStoreIdentityKey = "IdentityKeyStoreIdentityKey"
    private let LocalRegistrationIdKey = "LocalRegistrationIdKey"

    public var delegate: SignalLibraryStoreDelegate

    public var context: SignalContext!

    public enum LibraryStoreType: String {
        case session
        case preKey
        case signedPreKey
        case identityKey
        case senderKey
        case currentSignedPreKey
        case localRegistrationId
    }

    struct SignalLibrarySessionRecord: Codable, Hashable {
        var key: String
        var deviceId: Int32
        var data: Data
    }

    struct SignalLibraryPreKeyRecord: Codable, Hashable {
        var key: UInt32
        var data: Data
    }

    struct SignalLibraryIdentityKeyRecord: Codable, Hashable {
        var key: String
        var data: Data
    }

    struct SignalLibrarySenderKeyRecord: Codable, Hashable {
        var key: String
        var data: Data
    }

    @objc public var identityKeyPair: SignalIdentityKeyPair? {
        guard let data = self.identityKeyStore[IdentityKeyStoreIdentityKey]?.data as NSData? else {
            return nil
        }

        var key_pair: UnsafeMutablePointer<ratchet_identity_key_pair>?
        ratchet_identity_key_pair_deserialize(&key_pair, data.bytes.assumingMemoryBound(to: UInt8.self), data.length, self.context.context)

        return SignalIdentityKeyPair(identityKeyPair: key_pair!)
    }

    @objc public var localRegistrationId: UInt32 {
        set {
            let value = NSNumber(value: newValue)
            let data = NSKeyedArchiver.archivedData(withRootObject: value)
            self.delegate.storeSignalLibraryValue(data, key: LocalRegistrationIdKey, type: .localRegistrationId)
        }
        get {
            guard let data = self.delegate.retrieveSignalLibraryValue(key: LocalRegistrationIdKey, type: .localRegistrationId),
                let value = NSKeyedUnarchiver.unarchiveObject(with: data) as? NSNumber else {
                return 0
            }

            return value.uint32Value
        }
    }

    private var currentlySignedPreKeyId: UInt32 {
        didSet {
            let value = NSNumber(value: self.currentlySignedPreKeyId)
            let data = NSKeyedArchiver.archivedData(withRootObject: value)
            self.delegate.storeSignalLibraryValue(data, key: LibraryStoreType.currentSignedPreKey.rawValue, type: .currentSignedPreKey)
        }
    }

    private(set) var sessionStore: [String: [[Int32: SignalLibrarySessionRecord]]]

    private(set) var preKeyStore: [UInt32: SignalLibraryPreKeyRecord] {
        didSet {
            let newValues = self.preKeyStore.filter { v -> Bool in
                return !oldValue.keys.contains(v.key)
            }
            for item in newValues {
                let prekeyData = try! JSONEncoder().encode(item.value)
                self.delegate.storeSignalLibraryValue(prekeyData, key: "prekey: \(item.key)", type: .preKey)
            }
        }
    }

    private(set) var signedPreKeyStore: [UInt32: SignalLibraryPreKeyRecord] {
        didSet {
            for item in self.signedPreKeyStore {
                let prekeyData = try! JSONEncoder().encode(item.value)
                self.delegate.storeSignalLibraryValue(prekeyData, key: "signedprekey: \(item.key)", type: .signedPreKey)
            }
        }
    }

    private(set) var identityKeyStore: [String: SignalLibraryIdentityKeyRecord] {
        didSet {
            let newValues = self.identityKeyStore.filter { v -> Bool in
                return !oldValue.keys.contains(v.key)
            }
            for item in newValues {
                let identityKeyData = try! JSONEncoder().encode(item.value)
                self.delegate.storeSignalLibraryValue(identityKeyData, key: item.key, type: .identityKey)
            }
        }
    }

    private(set) var senderKeyStore: [String: Data] {
        didSet {
            for item in self.senderKeyStore {
                let record = SignalLibrarySenderKeyRecord(key: item.key, data: item.value)
                let identityKeyData = try! JSONEncoder().encode(record)
                self.delegate.storeSignalLibraryValue(identityKeyData, key: item.key, type: .senderKey)
            }
        }
    }

    public init(delegate: SignalLibraryStoreDelegate) {
        self.delegate = delegate

        // restore currently signed prekey data from db.
        if let currentlySignedPreKeyData = self.delegate.retrieveSignalLibraryValue(key: LibraryStoreType.currentSignedPreKey.rawValue, type: .currentSignedPreKey) {

            let number = NSKeyedUnarchiver.unarchiveObject(with: currentlySignedPreKeyData) as? NSNumber
            self.currentlySignedPreKeyId = number?.uint32Value ?? .max
        } else {
            self.currentlySignedPreKeyId = .max
        }

        let decoder = JSONDecoder()

        // reload prekeys from db
        let prekeysData = self.delegate.retrieveAllSignalLibraryValue(ofType: .preKey)
        var prekeys: [UInt32: SignalLibraryPreKeyRecord] = [:]

        for prekeyData in prekeysData {
            let preKeyRecord = try! decoder.decode(SignalLibraryPreKeyRecord.self, from: prekeyData)
            prekeys[preKeyRecord.key] = preKeyRecord
        }

        self.preKeyStore = prekeys

        // reload signed prekey from db
        let signedPrekeysData = self.delegate.retrieveAllSignalLibraryValue(ofType: .signedPreKey)
        var signedPreKeys: [UInt32: SignalLibraryPreKeyRecord] = [:]

        for signedPreKeyData in signedPrekeysData {
            let signedPreKeyRecord = try! decoder.decode(SignalLibraryPreKeyRecord.self, from: signedPreKeyData)
            signedPreKeys[signedPreKeyRecord.key] = signedPreKeyRecord
        }

        self.signedPreKeyStore = signedPreKeys

        // load session data from db
        let sessionsData = self.delegate.retrieveAllSignalLibraryValue(ofType: .session)
        var sessions: [String: [[Int32: SignalLibrarySessionRecord]]] = [:]

        for sessionData in sessionsData {
            let sessionRecord = try! decoder.decode(SignalLibrarySessionRecord.self, from: sessionData)
            if sessions[sessionRecord.key] == nil {
                sessions[sessionRecord.key] = []
            }

            sessions[sessionRecord.key]!.append([sessionRecord.deviceId: sessionRecord])
        }

        self.sessionStore = sessions

        // load session data from db
        let senderKeysData = self.delegate.retrieveAllSignalLibraryValue(ofType: .senderKey)
        var senderKeys: [String: Data] = [:]

        for senderKeyData in senderKeysData {
            let senderKeyRecord = try! decoder.decode(SignalLibrarySenderKeyRecord.self, from: senderKeyData)
            senderKeys[senderKeyRecord.key] = senderKeyRecord.data
        }

        self.senderKeyStore = senderKeys

        // load identity keys from db
        let identityKeysData = self.delegate.retrieveAllSignalLibraryValue(ofType: .identityKey)
        var identityKeys: [String: SignalLibraryIdentityKeyRecord] = [:]

        for identityKeyData in identityKeysData {
            let identityKeyRecord = try! decoder.decode(SignalLibraryIdentityKeyRecord.self, from: identityKeyData)
            identityKeys[identityKeyRecord.key] = identityKeyRecord
        }

        self.identityKeyStore = identityKeys

        super.init()
    }

    private let currentlySignedPreKeyStoreKey = UInt32.max

    // MARK: SignalSessionStore
    @objc public func deviceSessionRecord(for addressName: String, deviceId: Int32) -> Data? {
        guard let sessions = self.sessionStore[addressName], let session = sessions.first(where: { dict -> Bool in
            dict[deviceId] != nil
        }) else {
            return nil
        }

        let sessionRecord = session[deviceId]

        return sessionRecord?.data
    }

    /**
     * Returns a copy of the serialized session record corresponding to the
     * provided recipient ID + device ID tuple.
     * or nil if not found.
     */
    @objc public func sessionRecord(for address: SignalAddress) -> Data {
        guard let deviceSession = self.deviceSessionRecord(for: address.name, deviceId: address.deviceId) else {
            var record: UnsafeMutablePointer<session_record>?
            var state: UnsafeMutablePointer<session_state>?
            session_state_create(&state, self.context.context)
            session_record_create(&record, state, self.context.context)

            var buffer: UnsafeMutablePointer<signal_buffer>?
            session_record_serialize(&buffer, record)
            let data = Data(bytes: signal_buffer_data(buffer), count: signal_buffer_len(buffer))

            signal_buffer_free(buffer)

            return data
        }

        return deviceSession
    }

    /**
     * Commit to storage the session record for a given
     * recipient ID + device ID tuple.
     *
     * Return YES on success, NO on failure.
     */
    @objc public func storeSessionRecord(_ recordData: Data, for address: SignalAddress) -> Bool {
        let newSessionRecord = SignalLibrarySessionRecord(key: address.name, deviceId: address.deviceId, data: recordData)

        if let array = self.sessionStore[address.name] {
            for (index, element) in array.enumerated() {
                if element.keys.first == address.deviceId {
                    self.sessionStore[address.name]![index] = [address.deviceId: newSessionRecord]
                }
            }
        } else {
            self.sessionStore[address.name] = [[address.deviceId: newSessionRecord]]
        }

        let sessionData = try! JSONEncoder().encode(newSessionRecord)
        self.delegate.storeSignalLibraryValue(sessionData, key: address.nameForStoring, type: .session)

        return self.sessionRecordExists(for: address)
    }

    /**
     * Determine whether there is a committed session record for a
     * recipient ID + device ID tuple.
     */
    @objc public func sessionRecordExists(for address: SignalAddress) -> Bool {
        let record = self.sessionRecord(for: address)

        let sessionRecord = SessionRecord(data: record, signalContext: self.context)

        let hasSenderChain = sessionRecord.sessionRecordPointer.pointee.state.pointee.has_sender_chain == 1

        return hasSenderChain
    }

    /**
     * Remove a session record for a recipient ID + device ID tuple.
     */
    @objc public func deleteSessionRecord(for address: SignalAddress) -> Bool {
        while self.sessionRecordExists(for: address) {
            self.sessionStore.removeValue(forKey: address.name)
        }

        return self.sessionStore[address.name] == nil
    }

    /**
     * Remove the session records corresponding to all devices of a recipient ID.
     *
     * @return the number of deleted sessions on success, negative on failure
     */
    @objc public func deleteAllDeviceSessions(for addressName: String) -> Int32 {
        let count = Int32(self.sessionStore[addressName]?.count ?? 0)

        self.sessionStore.removeValue(forKey: addressName)

        return count
    }

    // MARK: SignalPreKeyStore
    /**
     * Load a local serialized PreKey record.
     * return nil if not found
     */
    @objc public func loadPreKey(with id: UInt32) -> Data? {
        return self.preKeyStore[id]?.data
    }

    /**
     * Store a local serialized PreKey record.
     * return YES if storage successful, else NO
     */
    @discardableResult @objc public func storePreKey(data: Data, id: UInt32) -> Bool {
        self.preKeyStore[id] = SignalLibraryPreKeyRecord(key: id, data: data)

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
        self.preKeyStore.removeValue(forKey: id)

        return self.preKeyStore[id] == nil
    }

    public func nextPreKeyId() -> UInt32 {
        guard let lastKey = self.preKeyStore.keys.sorted().last else { return 1 }

        return lastKey + 1
    }

    // MARK: SignalSignedPreKeyStore
    /**
     * Load a local serialized signed PreKey record.
     */
    @objc public func loadSignedPreKey(with signedPreKeyId: UInt32) -> Data? {
        return self.signedPreKeyStore[signedPreKeyId]?.data
    }

    /**
     * Store a local serialized signed PreKey record.
     */
    @discardableResult
    @objc public func storeSignedPreKey(_ signedPreKey: Data?, signedPreKeyId: UInt32) -> Bool {
        if let signedPreKey = signedPreKey {
            self.signedPreKeyStore[signedPreKeyId] = SignalLibraryPreKeyRecord(key: signedPreKeyId, data: signedPreKey)
        } else {
            self.removeSignedPreKey(with: signedPreKeyId)
        }

        return self.containsSignedPreKey(with: signedPreKeyId)
    }

    /**
     * Determine whether there is a committed signed PreKey record matching
     * the provided ID.
     */
    @objc public func containsSignedPreKey(with signedPreKeyId: UInt32) -> Bool {
        return self.signedPreKeyStore[signedPreKeyId] != nil
    }

    /**
     * Delete a SignedPreKeyRecord from local storage.
     */
    @discardableResult
    @objc public func removeSignedPreKey(with signedPreKeyId: UInt32) -> Bool {
        self.signedPreKeyStore.removeValue(forKey: signedPreKeyId)

        return true
    }

    public func retrieveCurrentSignedPreKeyId() -> UInt32 {
        return self.currentlySignedPreKeyId
    }

    public func storeCurrentSignedPreKeyId(_ id: UInt32) -> Bool {
        self.currentlySignedPreKeyId = id

        return self.currentlySignedPreKeyId != .max
    }

    /**
     * Save a remote client's identity key
     * <p>
     * Store a remote client's identity key as trusted.
     * The value of key_data may be null. In this case remove the key data
     * from the identity store, but retain any metadata that may be kept
     * alongside it.
     */
    public func saveRemoteIdentity(with address: SignalAddress, identityKey: Data?) -> Bool {
        if let identityKey = identityKey {
            self.identityKeyStore[address.name] = SignalLibraryIdentityKeyRecord(key: address.name, data: identityKey)
        } else {
            self.identityKeyStore[address.name] = nil
        }

        return self.identityKeyStore[address.name] != nil
    }

    public func saveIdentity(_ identityKey: Data?) -> Bool {
        if let identityKey = identityKey {
            self.identityKeyStore[IdentityKeyStoreIdentityKey] = SignalLibraryIdentityKeyRecord(key: self.IdentityKeyStoreIdentityKey, data: identityKey)
        } else {
            self.identityKeyStore[IdentityKeyStoreIdentityKey] = nil
        }

        return self.identityKeyStore[IdentityKeyStoreIdentityKey] != nil
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
        guard let existingKey = self.identityKeyStore[address.name] else {
            return true
        }

        if existingKey.data == identityKey {
            return true
        }

        return false
    }

    // MARK: SignalSenderKeyStore
    func key(for address: SignalAddress, groupId: String) -> String {
        return "\(address.name)\(address.deviceId)\(groupId)"
    }

    /**
     * Store a serialized sender key record for a given
     * (groupId + senderId + deviceId) tuple.
     */
    @objc public func storeSenderKey(with data: Data, signalAddress: SignalAddress, groupId: String) -> Bool {
        let key = self.key(for: signalAddress, groupId: groupId)
        self.senderKeyStore[key] = data

        return true
    }

    /**
     * Returns a copy of the sender key record corresponding to the
     * (groupId + senderId + deviceId) tuple.
     */
    @objc public func loadSenderKey(for address: SignalAddress, groupId: String) -> Data? {
        let key = self.key(for: address, groupId: groupId)
        return self.senderKeyStore[key]
    }

    @objc public func allDeviceIds(for addressName: String) -> [Int32] {
        if let records = self.sessionStore[addressName] {
            return Array(records.map({ r in r.keys }).joined())
        }

        return []
    }
}
