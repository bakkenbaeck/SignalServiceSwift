//
//  SignalServiceSwiftTests.swift
//  SignalServiceSwiftTests
//
//  Created by Igor Ranieri on 17.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import XCTest
@testable import SignalServiceSwift

class SignalServiceSwiftTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testExample() {

        let aliceAddress =  SignalAddress(name: "alice", deviceId: 1)
        let bobAddress = SignalAddress(name: "bob", deviceId: 1)

        // Create Alice
        let inMemoryStore = SignalStoreInMemoryStorage()
        let concreteStore = SignalProtocolStore(signalStore: inMemoryStore)
        let signalContext = SignalContext(store: concreteStore)
        let keyHelper = SignalKeyHelper(context: signalContext)

        concreteStore.setup(with: signalContext.context)

        let registrationId = keyHelper.generateRegistrationId()
        guard let identityKeyPair = keyHelper.generateIdentityKeyPair() else {
            XCTFail()

            return
        }

        inMemoryStore.identityKeyPair = identityKeyPair
        inMemoryStore.localRegistrationId = registrationId

        let preKeys = keyHelper.generatePreKeys(withStartingPreKeyId: 1, count: 100)
        XCTAssertEqual(preKeys.count, 100)

        let preKey0 = preKeys.first!

        let signedPreKey = keyHelper.generateSignedPreKey(withIdentity: identityKeyPair, signedPreKeyId: 0)

        XCTAssertTrue(inMemoryStore.storePreKey(data: preKey0.serializedData, id: preKey0.preKeyId))
        XCTAssertTrue(inMemoryStore.storeSignedPreKey(signedPreKey.serializedData, signedPreKeyId: signedPreKey.preKeyId))

        guard let alicePreKeyBundle = SignalPreKeyBundle(registrationId: registrationId, deviceId: aliceAddress.deviceId, preKeyId: preKey0.preKeyId, preKeyPublic: preKey0.keyPair.publicKey, signedPreKeyId: signedPreKey.preKeyId, signedPreKeyPublic: signedPreKey.keyPair.publicKey, signature: signedPreKey.signature as NSData, identityKey: identityKeyPair.publicKey) else {

            XCTFail()
            fatalError()
        }

        // Create Bob
        let bobInMemoryStore = SignalStoreInMemoryStorage()
        let bobConcreteStore = SignalProtocolStore(signalStore: bobInMemoryStore)
        let bobSignalContext = SignalContext(store: bobConcreteStore)

        bobConcreteStore.setup(with: bobSignalContext.context)

        let bobKeyHelper = SignalKeyHelper(context: bobSignalContext)

        guard let bobIdentityKeyPair = bobKeyHelper.generateIdentityKeyPair() else {
            XCTFail()
            return
        }
        let bobLocalRegistrationId = bobKeyHelper.generateRegistrationId()

        bobInMemoryStore.identityKeyPair = bobIdentityKeyPair
        bobInMemoryStore.localRegistrationId = bobLocalRegistrationId

        let bobPreKeys = bobKeyHelper.generatePreKeys(withStartingPreKeyId: 1, count: 100)
        XCTAssertEqual(bobPreKeys.count, 100)

        let bobSignedPreKey = bobKeyHelper.generateSignedPreKey(withIdentity: bobIdentityKeyPair, signedPreKeyId: 0)

        let bobPreKey0 = bobPreKeys.first!
        XCTAssertTrue(bobInMemoryStore.storePreKey(data: bobPreKey0.serializedData, id: bobPreKey0.preKeyId))
        XCTAssertTrue(bobInMemoryStore.storeSignedPreKey(bobSignedPreKey.serializedData, signedPreKeyId: bobSignedPreKey.preKeyId))

        guard let bobPreKeyBundle = SignalPreKeyBundle(registrationId: bobLocalRegistrationId, deviceId: bobAddress.deviceId, preKeyId: bobPreKey0.preKeyId, preKeyPublic: bobPreKey0.keyPair.publicKey, signedPreKeyId: bobSignedPreKey.preKeyId, signedPreKeyPublic: bobSignedPreKey.keyPair.publicKey, signature: bobSignedPreKey.signature as NSData, identityKey: bobIdentityKeyPair.publicKey) else {

            XCTFail()
            return
        }

        XCTAssertNotNil(bobPreKeyBundle)


        guard let bobSessionBuilder = SignalSessionBuilder(address: aliceAddress, context: bobSignalContext) else {
            XCTFail()
            return
        }

        let result = bobSessionBuilder.processPreKeyBundle(alicePreKeyBundle)
        XCTAssertTrue(result)

        let bobSessionCipher = SignalSessionCipher(address: aliceAddress, context: bobSignalContext)
        let bobMessage = "Hey, it's a me, tha bob!"



        guard let bobCiphertext = try! bobSessionCipher.encrypt(message: bobMessage) else {
            XCTFail()
            return
        }

        let aliceSessionCipher = SignalSessionCipher(address: bobAddress, context: signalContext)
        guard let decryptedBobMessageData = try! aliceSessionCipher.decrypt(cipher: bobCiphertext, ciphertextType: bobCiphertext.ciphertextType)  else {
            XCTFail()
            return
        }

        let decryptedBobString = IncomingSignalMessage(from: decryptedBobMessageData, chatId: "1")!

        XCTAssertEqual(bobMessage, decryptedBobString.body)
    }

//    func testWebSocketStuff() {
//        let inMemoryStore = SignalStoreInMemoryStorage()
//        let concreteStore = SignalProtocolStore(signalStore: inMemoryStore)
//        let signalContext = SignalContext(store: concreteStore)
//        let signalKeyHelper = SignalKeyHelper(context: signalContext)
//
//        let store = SignalStore()
//
//        concreteStore.setup(with: signalContext.context)
//
//        let username = "0x4a78c0c1c744152cdc03352fced626818c10e2a3"
//        let pwd =  "9B72DEAA-E951-481C-AB8F-4224F10E5708"
//        let signalingKey = "n4y2CeegP0QkftaOtdUla6xnvdT4mGtrlNrZyMdsZAdKLtphdMzhbzENoDjSvtx17TYEqQ=="
//        let url = URL(string: "https://chat.internal.service.toshi.org")!
//
//        let client = SignalClient(baseURL: url, signalingKey: signalingKey, username: username, password: pwd, deviceId: 1, registrationId: 1, signalKeyHelper: signalKeyHelper, signalContext: signalContext, store: store)
//
//        let expectation = XCTestExpectation(description: "123")
//        wait(for: [expectation], timeout: 1000)
//
//        DispatchQueue.main.asyncAfter(deadline: .now() + 100) {
//            print(client)
//
//            expectation.fulfill()
//        }
//    }
}
