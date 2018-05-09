//
//  NetworkClient.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 09.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Teapot

let PreKeysMininumCount = 35

class NetworkClient {
    var teapot: Teapot

    var baseURL: URL {
        return self.teapot.baseURL
    }

    let baseAuthHeaderFields: [String: String]

    public var allowsCellularDownload: Bool = false

    private var backgroundQueue = DispatchQueue(label: "com.bakkenbaeck.PreKeysQueue", qos: .background)

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

    func fetchPreKeyBundle(for recipientName: String, completion: @escaping ((SignalPreKeyBundle?) -> Void)) {
        self.fetchTimestamp { _ in
            // GET/v2/keys/{eth_address}/{device_id}, always use * wildcard for device_id.
            let path = "/v2/keys/\(recipientName)/*"

            self.teapot.get(path, headerFields: self.baseAuthHeaderFields) { result in
                switch result {
                case .failure:
                    NSLog("failed to retrieve prekey bundle for user: \(recipientName)")
                    completion(nil)
                case .success(let params, _):
                    if DebugLevel.current == .verbose {
                        NSLog("Fetched prekey bundle")
                    }
                    if let dict = params?.dictionary, let preKeyBundle = SignalPreKeyBundle(dict) {
                        completion(preKeyBundle)
                    }
                }
            }
        }
    }

    func sendMessage(_ messagesDict: [[String: Any]], from sender: SignalSender, to recipientAddress: String, completion: @escaping ((_ success: Bool, _ params: [String: Any], _ statusCode: Int) -> Void)) {
        self.fetchTimestamp { timestamp in
            let timestamp = Date().milisecondTimeIntervalSinceEpoch

            let payload: [String: Any] = [
                "timestamp": timestamp,
                "messages": messagesDict
            ]

            let path = "/v1/messages/\(recipientAddress)"
            let requestParameters = RequestParameter(payload)

            self.teapot.put(path, parameters: requestParameters, headerFields: self.baseAuthHeaderFields) { result in
                switch result {
                case .success(let params, let request):
                    completion(true, params?.dictionary ?? [:], request.statusCode)
                case .failure(let params, let request, let error):
                    NSLog(error.description)
                    completion(false, params?.dictionary ?? [:], request.statusCode)
                }
            }
        }
    }

    func checkPreKeys(in context: SignalContext, sender: SignalSender) {
        let path = "/v2/keys"

        self.teapot.get(path, headerFields: self.baseAuthHeaderFields) { result in
            switch result {
            case .success(let params, _):
                guard let dict = params?.dictionary, let count = dict["count"] as? Int else {
                    fatalError("Could not retrieve count from dictionary")
                }

                let shouldUpdateOneTimePreKeys = count < PreKeysMininumCount
                if shouldUpdateOneTimePreKeys {
                    self.updateOneTimePreKeys(context: context, mode: .signedAndOneTime)
                } else {
                    var shouldUpdateSignedPrekey = false

                    if let currentSignedPreKeyId = context.currentlySignedPreKeyId, let currentSignedPreKeyData = context.store.signedPreKeyStore.loadSignedPreKey(with: currentSignedPreKeyId), let signedPreKey = SignalSignedPreKey(serializedData: currentSignedPreKeyData) {

                        shouldUpdateSignedPrekey = signedPreKey.timestamp.daysSince(Date()) >= 3
                    } else {
                        shouldUpdateSignedPrekey = true
                    }

                    if shouldUpdateSignedPrekey {
                        self.updateOneTimePreKeys(context: context, mode: .signedOnly)
                    }

                    if !shouldUpdateSignedPrekey && !shouldUpdateOneTimePreKeys {
                        // If we didn't update the prekeys, our local "current signed key" state should
                        // agree with the service's "current signed key" state.  Let's verify that.
                        let path = "/v2/keys/signed"
                        self.teapot.get(path, headerFields: self.baseAuthHeaderFields) { signedKeyResult in
                            switch signedKeyResult {
                            case .success(let param, _):

                                guard let currentSignedPreKeyId = context.currentlySignedPreKeyId,
                                    let currentSignedPreKeyData = context.store.signedPreKeyStore.loadSignedPreKey(with: currentSignedPreKeyId),
                                    let signedPreKey = SignalSignedPreKey(serializedData: currentSignedPreKeyData) else {
                                    NSLog("No current signed prekey!?")
                                    return
                                }

                                guard let responseDictionary = param?.dictionary,
                                    let serverSignedPreKeyId = responseDictionary["keyId"] as? UInt32,
                                    let serverSignature = responseDictionary["signature"] as? String
                                else {
                                    fatalError() // something is wrooong!
                                }

                                guard serverSignedPreKeyId == currentSignedPreKeyId,
                                    serverSignature == signedPreKey.signature.base64EncodedString() else {
                                    NSLog("Could not verify signature for signed prekey. Not a match")
                                    return
                                }

                            case .failure(_, _, let error):
                                NSLog(error.localizedDescription)
                            }
                        }
                    }
                }

            case .failure(_, _, let error):
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
            case .failure: // (let json, let response, let error):
                NSLog("Could not fetch timestamp.")
                break
            }
        }
    }

    func clearSignedPreKeyRecords(signedPreKey: SignalSignedPreKey, context: SignalContext) {
        _ = context.store.signedPreKeyStore.removeSignedPreKey(with: signedPreKey.preKeyId)
    }

    func updateOneTimePreKeys(context: SignalContext, mode: RefreshPreKeysMode) {
        self.backgroundQueue.async {
            // generate a new signed prekey
            let signedPreKey = SignalSignedPreKey(withIdentityKeyPair: context.identityKeyPair!, signalContext: context)
            // Store the new signed key immediately, before it is sent to the
            // service to prevent race conditions and other edge cases.
            context.store.signedPreKeyStore.storeSignedPreKey(signedPreKey.serializedData, signedPreKeyId: signedPreKey.preKeyId)

            let success: () -> Void = {
                context.store.signedPreKeyStore.storeCurrentSignedPreKeyId(signedPreKey.preKeyId)
                self.clearSignedPreKeyRecords(signedPreKey: signedPreKey, context: context)
            }

            switch mode {
            case .signedAndOneTime:
                let nextPreKeyId = context.nextPreKeyId()
                let preKeys = context.signalKeyHelper.generatePreKeys(withStartingPreKeyId: nextPreKeyId, count: 100)

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

                let publicIdentityKeyString = context.identityKeyPair!.publicKey.base64EncodedString()

                let signedPreKeyDict: [String: Any] = [
                    "keyId": signedPreKey.preKeyId,
                    "publicKey": signedPreKey.keyPair.publicKey.base64EncodedString(),
                    "signature": signedPreKey.signature.base64EncodedString()
                ]

                let registrationParameters: [String: Any] = [
                    "preKeys": serializedPrekeyList,
                    "signedPreKey": signedPreKeyDict,
                    "identityKey": publicIdentityKeyString
                ]

                let path = "/v2/keys"
                let parameters = RequestParameter(registrationParameters)

                self.teapot.put(path, parameters: parameters, headerFields: self.baseAuthHeaderFields) { result in
                    switch result {
                    case .success:
                        success()
                    case .failure(_, _, let error):
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
                    case .success:
                        success()
                    case .failure(_, _, let error):
                        NSLog(error.localizedDescription)
                    }
                }
            }
        }
    }

    func getAttachmentLocation(attachmentId: UInt64, completion: @escaping (_ location: String?) -> Void) {
        let path = String(format: "/v1/attachments/%llu", attachmentId)

        self.teapot.get(path, headerFields: self.baseAuthHeaderFields, allowsCellular: self.allowsCellularDownload) { result in
            var location: String?
            defer {
                DispatchQueue.main.async {
                    completion(location)
                }
            }

            switch result {
            case .success(let param, _):
                guard let dict = param?.dictionary else { return }
                location = dict["location"] as? String
            case .failure(_, _, let error):
                NSLog("Could not fetch attachment \(error.localizedDescription)")
            }
        }
    }

    func allocateAttachment(data: Data, completion: @escaping (_ pointer: SignalServiceAttachmentPointer?) -> Void) {
        let path = "/v1/attachments"

        self.teapot.get(path, headerFields: self.baseAuthHeaderFields) { result in
            switch result {
            case .success(let params, _):
                guard let dict = params?.dictionary else { fatalError("Could not retrieve allocated attachment info.") }

                let serverId = dict["id"] as! UInt64
                let location = dict["location"] as! String

                var key: NSData = NSData()
                var digest: NSData = NSData()
                let encryptedData = Cryptography.encryptAttachmentData(data, outKey: &key, outDigest: &digest)

                var pointer = SignalServiceAttachmentPointer(serverId: 0, key: key as Data, digest: digest as Data, size: 0, contentType: "image/png")
                pointer.attachmentData = data

                let url = URL(string: location)!
                var request = URLRequest(url: url)
                request.httpMethod = "PUT"
                request.httpBody = encryptedData
                request.allHTTPHeaderFields = ["Content-Type": "application/octet-stream"]

                let task = self.teapot.session.uploadTask(with: request, from: encryptedData) { _, response, error in
                    guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                        NSLog("Could not upload data. \(error?.localizedDescription ?? "")")
                        completion(nil)
                        return
                    }

                    pointer.serverId = serverId

                    completion(pointer)
                }

                task.resume()
            case .failure(_, _, let error):
                NSLog("Could not fetch attachment \(error.localizedDescription)")
                completion(nil)
            }
        }
    }
}
