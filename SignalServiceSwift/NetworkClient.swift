//
//  NetworkClient.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 09.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation
import Teapot

let PreKeysMininumCount = 35


extension Int {
    /// Returns a TimeInterval for an approximate number of days.
    /// Ex: 3.days == 259200 seconds. Of courrse is not Date/Time aware. Use it with care.
    ///
    /// Same as .days, but for the sake of grammatical order, we have both plural and singular.
    var day: TimeInterval {
        return self.days
    }

    /// Returns a TimeInterval for an approximate number of days.
    /// Ex: 3.days == 259200 seconds. Of courrse is not Date/Time aware. Use it with care.
    var days: TimeInterval {
        return TimeInterval(self * 60 * 60 * 24)
    }
}


class NetworkClient {
    var teapot: Teapot

    var baseURL: URL {
        return self.teapot.baseURL
    }

    let baseAuthHeaderFields: [String: String]

    private var preKeyQueue = DispatchQueue.init(label: "com.bakkenbaeck.PreKeysQueue", qos: .background)

    enum RefreshPreKeysMode {
        case signedAndOneTime
        case signedOnly
    }

    init(baseURL: URL, username: String?, password: String?) {
        self.teapot = Teapot(baseURL: baseURL)

        if let username = username, let password = password {
            self.baseAuthHeaderFields = self.teapot.basicAuthenticationHeader(username: username, password: password)
        } else {
            self.baseAuthHeaderFields = [:]
        }
    }

    func fetchPreKeyBundle(for recipientName: String, completion: @escaping((SignalPreKeyBundle) -> Void)) {
        self.fetchTimestamp({ timestamp in
            // GET/v2/keys/{eth_address}/{device_id}, always use * wildcard for device_id.
            let path = "/v2/keys/\(recipientName)/*"

            self.teapot.get(path, headerFields: self.baseAuthHeaderFields) { result in
                switch result {
                case .failure(_, _, _):
                    NSLog("failed to retrieve pre key bundle for user: \(recipientName)")
                case let .success(params, _):
                    NSLog("Fetched prekey bundle")
                    if let dict = params?.dictionary, let preKeyBundle = SignalPreKeyBundle(dict) {
                        completion(preKeyBundle)
                    }
                }
            }
        })
    }

    func sendMessage(_ message: OutgoingSignalMessage, from sender: SignalSender, to recipient: SignalRecipient, in chat: SignalChat, completion: @escaping((_: Bool) -> Void)) {
        // if chat is 1:1
        // TODO: group chat
        self.fetchTimestamp({ timestamp in
            let timestamp = UInt64(timestamp * 1000)

            let type = (message.ciphertext?.ciphertextType ?? .unknown).rawValue

            let payload: [String: Any] = [
                "timestamp": timestamp,
                "messages": [
                    [
                        "type": type,
                        "destination": recipient.name,
                        "destinationDeviceId": recipient.deviceId,
                        "destinationRegistrationId": recipient.remoteRegistrationId,
                        "content": message.encryptedBodybase64Encoded(),
                        "isSilent": false
                    ]
                ]
            ]

            let path = "/v1/messages/\(recipient.name)"

            let requestParameters = RequestParameter(payload)

            self.teapot.put(path, parameters: requestParameters, headerFields: self.baseAuthHeaderFields) { result in
                switch result {
                case let .success(params, response):
                    completion(true)
// Send a sync receipt if it's an outgoing message
//                    if let message = message as? OutgoingMessage {
//                        let outgoingMessage = OutgoingSentMessageTranscript(message: message)
//                        let recipient = SignalRecipient(name: sender.username, deviceId: sender.deviceId,
//                                                              remoteRegistrationId: sender.remoteRegistrationId)
//                        self.sendMessage(outgoingMessage, from: sender, to: recipient)
//                    }
                case .failure(_, _, let error):
                    completion(false)
                    NSLog(error.localizedDescription)
                }
            }
        })
    }

    func checkPreKeys(in context: SignalContext, signalKeyHelper: SignalKeyHelper, sender: SignalSender) {
        let path = "/v2/keys"

        self.teapot.get(path, headerFields: self.baseAuthHeaderFields) { result in
            switch result {
            case let .success(params, _):
                guard let dict = params?.dictionary, let count = dict["count"] as? Int else {
                    fatalError("Could not retrieve count from dictionary")
                }


                let shouldUpdateOneTimePreKeys = count < PreKeysMininumCount
                if shouldUpdateOneTimePreKeys  {
                    self.updateOneTimePreKeys(context: context, signalKeyHelper: signalKeyHelper, mode: .signedAndOneTime)
                } else {
                    var shouldUpdateSignedPrekey = false

                    if let currentSignedPreKeyId = context.currentlySignedPreKeyId, let currentSignedPreKeyData = context.store.signedPreKeyStore.loadSignedPreKey(withId: currentSignedPreKeyId), let signedPreKey = SignalSignedPreKey(serializedData: currentSignedPreKeyData) {

                        shouldUpdateSignedPrekey = signedPreKey.timestamp.timeIntervalSinceNow >= 2.days
                    } else {
                        shouldUpdateSignedPrekey = true
                    }

                    if shouldUpdateSignedPrekey {
                        self.updateOneTimePreKeys(context: context, signalKeyHelper: signalKeyHelper, mode: .signedOnly)
                    }

                    if !shouldUpdateSignedPrekey && !shouldUpdateOneTimePreKeys {
                        // If we didn't update the prekeys, our local "current signed key" state should
                        // agree with the service's "current signed key" state.  Let's verify that.
                        let path = "/v2/keys/signed"
                        self.teapot.get(path, headerFields: self.baseAuthHeaderFields) { signedKeyResult in
                            switch signedKeyResult {
                            case let .success(param, response):
                                let currentSignedPreKeyId = context.store.signedPreKeyStore.fetchCurrentSignedPreKeyId()

                                guard let responseDictionary = param?.dictionary,
                                let serverSignedPreKeyId = responseDictionary["keyId"] as? UInt32,
                                currentSignedPreKeyId == serverSignedPreKeyId else {
                                    fatalError() // something is wrooong!
                                }
                            case let .failure(params, response, error):
                                print(error)
                            }
                        }
                    }
                }

            case let .failure(_, _, error):
                print(error)
            }
        }
    }

    func fetchTimestamp(_ completion: @escaping ((Int) -> Void)) {
        self.teapot.get("/v1/accounts/bootstrap/") { (result: NetworkResult) in
            switch result {
            case .success(let json, let response):
                guard response.statusCode == 200 else { fatalError("Could not retrieve timestamp from chat service.") }
                guard let json = json?.dictionary else { fatalError("JSON dictionary not found in payload") }
                guard let timestamp = json["timestamp"] as? Int else { fatalError("Timestamp not found in json payload or not an integer.") }

                    completion(timestamp)
            case .failure(_, _, _): //(let json, let response, let error):
                NSLog("Could not fetch timestamp.")
                break
            }
        }
    }

    func updateOneTimePreKeys(context: SignalContext, signalKeyHelper: SignalKeyHelper, mode: RefreshPreKeysMode) {
        self.preKeyQueue.async {
            // generate a new signed pre key
            let signedPreKey = SignalSignedPreKey(withIdentityKeyPair: context.identityKeyPair, signalContext: context)
            // Store the new signed key immediately, before it is sent to the
            // service to prevent race conditions and other edge cases.
            context.store.signedPreKeyStore.storeSignedPreKey(signedPreKey.serializedData, signedPreKeyId: signedPreKey.preKeyId)

            switch mode {
            case .signedAndOneTime:
                let nextPreKeyId = context.nextPreKeyId()
                let preKeys = signalKeyHelper.generatePreKeys(withStartingPreKeyId: nextPreKeyId, count: 100)

                var serializedPrekeyList = [[String: Any]]()
                preKeys.forEach { key in
                    // Store the new one-time keys immediately, before they are sent to the
                    // service to prevent race conditions and other edge cases.
                    guard context.store.preKeyStore.storePreKey(data: key.serializedData, id: key.preKeyId) else { fatalError() }

                    serializedPrekeyList.append([
                        "keyId": key.preKeyId,
                        "publicKey": key.serializedData.base64EncodedString()
                        ])
                }

                let publicIdentityKeyString = context.identityKeyPair.publicKey.base64EncodedString()

                let signedPreKeyDict: [String : Any] = [
                    "keyId": signedPreKey.preKeyId,
                    "publicKey": signedPreKey.keyPair.publicKey.base64EncodedString(),
                    "signature": signedPreKey.signature.base64EncodedString()
                ]

                let registrationParameters: [String : Any] = [
                    "preKeys": serializedPrekeyList,
                    "signedPreKey": signedPreKeyDict,
                    "identityKey": publicIdentityKeyString
                ]

                let path = "/v2/keys"
                let parameters = RequestParameter(registrationParameters)

                self.teapot.put(path, parameters: parameters, headerFields: self.baseAuthHeaderFields) { result in
                    switch result {
                    case let .success(params, response):
//                        NSLog("%@", response)
                        break
                    case let .failure(_, _, error):
                        NSLog(error.localizedDescription)
                    }
                }
            case .signedOnly:
                let signedPreKeyDict: [String: Any] = [
                    "keyId": signedPreKey.preKeyId,
                    "publicKey": signedPreKey.keyPair.publicKey.base64EncodedString(),
                    "signature": signedPreKey.signature.base64EncodedString()
                ]
                let parameters = RequestParameter(signedPreKeyDict)

                let path = "/v2/keys/signed"

                self.teapot.put(path, parameters: parameters, headerFields: self.baseAuthHeaderFields) { result in
                    switch result {
                    case let .success(params, response):
                        context.store.signedPreKeyStore.storeCurrentSignedPreKeyId(signedPreKey.preKeyId)

//                        NSLog("%@", response)
                    case let .failure(params, response, error):
                        NSLog(error.localizedDescription)
                    }
                }
            }

        }
    }

}
