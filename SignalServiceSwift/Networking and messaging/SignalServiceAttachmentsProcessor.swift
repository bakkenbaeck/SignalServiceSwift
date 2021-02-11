//
//  SignalServiceAttachmentsProcessor.swift
//  SignalServiceSwift
//
//  Created by Igor Ranieri on 26.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

class SignalServiceAttachmentsProcessor {
    var message: SignalMessage
    var store: SignalServiceStore
    var networkClient: NetworkClient

    var attachmentIds = [String]()
    var supportedPointers = [SignalServiceAttachmentPointer]()
    var supportedIds = [String]()

    var hasSupportedAttachments: Bool {
        return self.supportedPointers.count > 0
    }

    init(attachments: [Signalservice_AttachmentPointer], message: SignalMessage, store: SignalServiceStore, networkClient: NetworkClient) {
        self.message = message
        self.store = store
        self.networkClient = networkClient

        var attachmentIds = [String]()
        var supportedPointers = [SignalServiceAttachmentPointer]()
        var supportedIds = [String]()

        for attachment in attachments {
            let pointer = SignalServiceAttachmentPointer(serverId: attachment.id, key: attachment.key, digest: attachment.digest, size: attachment.size, contentType: attachment.contentType)

            attachmentIds.append(pointer.uniqueId)
            try! self.store.save(attachmentPointer: pointer)
            supportedPointers.append(pointer)
            supportedIds.append(pointer.uniqueId)
        }

        self.attachmentIds = attachmentIds
        self.supportedPointers = supportedPointers
        self.supportedIds = supportedIds
    }

    func fetchAttachments() {
        for attachment in self.supportedPointers {
            self.retrieve(attachment)
        }
    }

    func retrieve(_ pointer: SignalServiceAttachmentPointer) {
        var pointer = pointer
        pointer.state = .downloading

        try? self.store.save(attachmentPointer: pointer)

        if pointer.serverId < 100 {
            NSLog("Suspicious attachment id %llu.", pointer.serverId)
        }

        self.networkClient.getAttachmentLocation(attachmentId: pointer.serverId) { location in
            guard let location = location else { fatalError("could not retrieve location") }

            self.download(from: location, pointer: pointer)
        }
    }

    func download(from location: String, pointer: SignalServiceAttachmentPointer) {
        guard let url = URL(string: location) else { return }
        var pointer = pointer

        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = ["Content-Type": "application/octet-stream"]
        let session = URLSession(configuration: configuration)

        let task = session.dataTask(with: url) { data, response, error in
            if let response = response as? HTTPURLResponse, response.statusCode != 200 {
                NSLog("Could not download attachment. \(response)")
                return
            }
            if let error = error {
                NSLog("Error \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                NSLog("Error, no data to decrypt for attachment.")
                return
            }

            let decryptedData = Cryptography.decryptAttachment(data, withKey: pointer.key, digest: pointer.digest, unpaddedSize: pointer.size)

            pointer.attachmentData = decryptedData
            try? self.store.save(attachmentPointer: pointer)

            self.message.attachmentPointerIds.append(pointer.uniqueId)
            try? self.store.save(self.message)
        }

        task.resume()
    }
}
