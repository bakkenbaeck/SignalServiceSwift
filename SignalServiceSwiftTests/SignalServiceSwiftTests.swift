//
//  SignalServiceSwiftTests.swift
//  SignalServiceSwiftTests
//
//  Created by Igor Ranieri on 17.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import XCTest
@testable import SignalServiceSwift

class TestsPersistenceStore: PersistenceStore {
    var serviceItems = [[String: AnyHashable]]()
    var libraryItems = [[String: AnyHashable]]()

    func retrieveAllObjects(ofType type: SignalServiceStore.PersistedType) -> [Data] {
        let valid = self.serviceItems.filter({ item -> Bool in
            return (item["type"] as? String) == type.rawValue
        })

        return valid.compactMap({ item -> Data? in
            return item["data"] as? Data
        })
    }

    func update(_ data: Data, key: String, type: SignalServiceStore.PersistedType) {
        let copy = self.serviceItems
        for (index, item) in copy.enumerated() {
            if item["key"] as? String == key && item["type"] as? String == type.rawValue {
                self.serviceItems[index] = ["key": key, "type": type.rawValue, "data": data]
            }
        }
    }

    func store(_ data: Data, key: String, type: SignalServiceStore.PersistedType) {
        self.serviceItems.append(["key": key, "type": type.rawValue, "data": data])
    }

    func storeSignalLibraryValue(_ value: Data, key: String, type: SignalLibraryStore.LibraryStoreType) {
        self.libraryItems.append(["key": key, "type": type.rawValue, "data": value])
    }

    func deleteSignalLibraryValue(key: String, type: SignalLibraryStore.LibraryStoreType) -> Bool {
        let copy = self.libraryItems
        for (index, item) in copy.enumerated() {
            if item["key"] as? String == key && item["type"] as? String == type.rawValue {
                self.libraryItems.remove(at: index)
            }
        }

        return true
    }

    func retrieveSignalLibraryValue(key: String, type: SignalLibraryStore.LibraryStoreType) -> Data? {
        return (self.libraryItems.first(where: { item -> Bool in
            return item["key"] as? String == key && item["type"] as? String == type.rawValue
        })?["data"] as? Data) ?? nil
    }

    func retrieveAllSignalLibraryValue(ofType type: SignalLibraryStore.LibraryStoreType) -> [Data] {
        let valid = self.libraryItems.filter({ item -> Bool in
            return (item["type"] as? String) == type.rawValue
        })

        return valid.compactMap({ item -> Data? in
            return item["data"] as? Data
        })
    }
}

class SignalServiceSwiftTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testEncodingDecoding() {
        let bobAddress = SignalAddress(name: "bob", deviceId: 1)

        // Create Alice
        let persistenceStore = TestsPersistenceStore()
        let aliceAddress =  SignalAddress(name: "alice", deviceId: 1)
        let inMemoryLibraryStore = SignalLibraryStore(delegate: persistenceStore)
        let concreteStore = SignalLibraryStoreBridge(signalStore: inMemoryLibraryStore)
        let signalContext = SignalContext(store: concreteStore)
        let keyHelper = SignalKeyHelper(context: signalContext)

        inMemoryLibraryStore.context = signalContext
        concreteStore.setup(with: signalContext.context)

        let registrationId = keyHelper.generateRegistrationId()
        guard let identityKeyPair = keyHelper.generateAndStoreIdentityKeyPair() else {
            XCTFail()

            return
        }

        _ = inMemoryLibraryStore.saveIdentity(identityKeyPair.serialized)
        inMemoryLibraryStore.localRegistrationId = registrationId

        let preKeys = keyHelper.generatePreKeys(withStartingPreKeyId: 1, count: 100)
        XCTAssertEqual(preKeys.count, 100)

        let preKey0 = preKeys.first!

        let signedPreKey = keyHelper.generateSignedPreKey(withIdentity: identityKeyPair, signedPreKeyId: 0)

        inMemoryLibraryStore.storePreKey(data: preKey0.serializedData, id: preKey0.preKeyId)
        inMemoryLibraryStore.storeSignedPreKey(signedPreKey.serializedData, signedPreKeyId: signedPreKey.preKeyId)

        guard let alicePreKeyBundle = SignalPreKeyBundle(registrationId: registrationId, deviceId: aliceAddress.deviceId, preKeyId: preKey0.preKeyId, preKeyPublic: preKey0.keyPair.publicKey, signedPreKeyId: signedPreKey.preKeyId, signedPreKeyPublic: signedPreKey.keyPair.publicKey, signature: signedPreKey.signature as NSData, identityKey: identityKeyPair.publicKey) else {

            XCTFail()
            fatalError()
        }

        // Create Bob
        let bobPersistenceStore = TestsPersistenceStore()
        let bobInMemoryStore = SignalLibraryStore(delegate: bobPersistenceStore)
        let bobConcreteStore = SignalLibraryStoreBridge(signalStore: bobInMemoryStore)
        let bobSignalContext = SignalContext(store: bobConcreteStore)

        bobInMemoryStore.context = bobSignalContext
        bobConcreteStore.setup(with: bobSignalContext.context)

        let bobKeyHelper = SignalKeyHelper(context: bobSignalContext)

        guard let bobIdentityKeyPair = bobKeyHelper.generateAndStoreIdentityKeyPair() else {
            XCTFail()
            return
        }
        let bobLocalRegistrationId = bobKeyHelper.generateRegistrationId()

        _ = bobInMemoryStore.saveIdentity(bobIdentityKeyPair.serialized)
        bobInMemoryStore.localRegistrationId = bobLocalRegistrationId

        let bobPreKeys = bobKeyHelper.generatePreKeys(withStartingPreKeyId: 1, count: 100)
        XCTAssertEqual(bobPreKeys.count, 100)

        let bobSignedPreKey = bobKeyHelper.generateSignedPreKey(withIdentity: bobIdentityKeyPair, signedPreKeyId: 0)

        let bobPreKey0 = bobPreKeys.first!
        bobInMemoryStore.storePreKey(data: bobPreKey0.serializedData, id: bobPreKey0.preKeyId)
        bobInMemoryStore.storeSignedPreKey(bobSignedPreKey.serializedData, signedPreKeyId: bobSignedPreKey.preKeyId)

        guard let bobPreKeyBundle = SignalPreKeyBundle(registrationId: bobLocalRegistrationId, deviceId: bobAddress.deviceId, preKeyId: bobPreKey0.preKeyId, preKeyPublic: bobPreKey0.keyPair.publicKey, signedPreKeyId: bobSignedPreKey.preKeyId, signedPreKeyPublic: bobSignedPreKey.keyPair.publicKey, signature: bobSignedPreKey.signature as NSData, identityKey: bobIdentityKeyPair.publicKey) else {

            XCTFail()
            return
        }

        XCTAssertNotNil(bobPreKeyBundle)


        let bobSessionBuilder = SignalSessionBuilder(address: aliceAddress, context: bobSignalContext)

        let result = bobSessionBuilder.processPreKeyBundle(alicePreKeyBundle)
        XCTAssertTrue(result)

        let bobSessionCipher = SignalSessionCipher(address: aliceAddress, context: bobSignalContext)
        let bobMessage = "Testing with UTF-32 👨‍👩‍👧!"

        let chat = SignalChat(recipientIdentifier: aliceAddress.name, in: SignalServiceStore(contactsDelegate: self))
        let outgoingBobMessage = OutgoingSignalMessage(recipientId: aliceAddress.name, chatId: chat.uniqueId, body: bobMessage, store: chat.store!)
        
        let bobCiphertext = try! bobSessionCipher.encrypt(message: outgoingBobMessage, in: chat)

        let aliceSessionCipher = SignalSessionCipher(address: bobAddress, context: signalContext)
        guard let decryptedBobMessageData = try! aliceSessionCipher.decrypt(cipher: bobCiphertext, ciphertextType: bobCiphertext.ciphertextType),
            let content = try? Signalservice_Content(serializedData: decryptedBobMessageData)
            else {
                XCTFail()
                return
        }

        XCTAssertTrue(content.hasDataMessage)
        XCTAssertEqual(bobMessage, content.dataMessage.body)
    }
}

extension SignalServiceSwiftTests: SignalRecipientsDelegate {
    func image(for address: String) -> UIImage? {
        return nil
    }

    func displayName(for address: String) -> String {
        return address
    }
}
