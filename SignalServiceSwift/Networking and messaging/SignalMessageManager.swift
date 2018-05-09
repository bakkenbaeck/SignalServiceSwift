//
//  SignalMessageManager.swift
//  SignalServiceSwift
//
//  Created by Igor Ranieri on 25.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

protocol SignalMessageManagerDelegate {
    func sendSocketMessageAcknowledgement(_ message: Signalservice_WebSocketMessage)
}

class SignalMessageManager {
    var sender: SignalSender
    var signalContext: SignalContext
    var networkClient: NetworkClient
    var store: SignalServiceStore
    var delegate: SignalMessageManagerDelegate

    init(sender: SignalSender, networkClient: NetworkClient, signalContext: SignalContext, store: SignalServiceStore, delegate: SignalMessageManagerDelegate) {
        self.sender = sender
        self.networkClient = networkClient
        self.signalContext = signalContext
        self.store = store
        self.delegate = delegate
    }

    func uploadAttachment(_ attachment: Data, in message: OutgoingSignalMessage, completion: @escaping (_ success: Bool) -> Void) {
        self.networkClient.allocateAttachment(data: attachment) { pointer in
            if let pointer = pointer {
                message.attachmentPointerIds.append(pointer.uniqueId)
                try? self.store.save(attachmentPointer: pointer)
            }

            completion(pointer != nil)
        }
    }

    func sendMessage(_ message: OutgoingSignalMessage, to recipient: SignalAddress, in chat: SignalChat, shouldPersistMessage: Bool = true, completion: @escaping (_ success: Bool) -> Void) {

        // no need to send a message to ourselves
        guard recipient.name != self.sender.username else {
            // self.handleReceiptSentToSelf(message, in: chat)

            return
        }

//        var retryAttempts = 3
        let messagesDict = self.deviceMessage(message, to: recipient, in: chat)
        if messagesDict.isEmpty {
            NSLog("Error. Could not send messages. Error encrypting.")

            message.messageState = .unsent

            if (shouldPersistMessage) {
                try? self.store.save(message)
            }

            return
        }

        self.networkClient.sendMessage(messagesDict, from: self.sender, to: recipient.name) { success, params, statusCode in
            if success {
                if !(message is TranscriptSignalMessage || message is ReadReceiptSignalMessage) && !message.didSentSyncTranscript {
                    message.didSentSyncTranscript = true
//                    let transcriptMessage = TranscriptSignalMessage(message: message, store: self.store)
//                    let selfRecipient = SignalAddress(name: self.sender.username, deviceId: 1)

//                    self.sendMessage(transcriptMessage, to: selfRecipient, in: chat, attachments: []) { success in
                    if (shouldPersistMessage) {
                        try? self.store.save(message)
                    }
//                    }
                }
            } else {
                defer {
                    message.messageState = .unsent
                    if (shouldPersistMessage) {
                        try? self.store.save(message)
                    }
                }

                let retrySending: (() -> Void) = { () -> Void in
//                    if retryAttempts <= 0 {
//                        // Since we've already repeatedly failed to send to the messaging API,
//                        // it's unlikely that repeating the whole process will succeed.
//                        return
//                    }
                    //
//                    retryAttempts -= 1

//                    NSLog("Retrying: %@.", messagesDict)

//                    self.sendMessage(message, to: recipient, in: chat, attachments: attachments, completion: completion)
                    completion(success)
                }

                switch statusCode {
                case 409:
                    // TODO: Not yet 100% sure what this is supposed to mean.
                    // At the moment I only get this when sending a message to self.
                    if DebugLevel.current == .verbose {
                        NSLog("Mismatched devices for recipient: %@.", recipient.name)
                    }

                    self.handleMismatchedDevices(params, recipientAddress: recipient.name, completion: retrySending)
                case 410:
                    // Stale devices. Usually a sign that the user re-installed or re-registered with the server.
                    if DebugLevel.current == .verbose {
                        NSLog("Stale devices for recipient: %@.", recipient.name)
                    }
                    self.handleStaleDevices(params, recipientAddress: recipient.name, completion: retrySending)
                default:
                    retrySending()
                }
            }
        }
    }

    func processSocketMessage(_ message: Signalservice_WebSocketMessage) {
        if message.request.path == "/api/v1/message", message.request.verb == "PUT" {
            let payload = Cryptography.decryptAppleMessagePayload(message.request.body, withSignalingKey: self.sender.signalingKey)
            guard let envelope = try? Signalservice_Envelope(serializedData: payload) else {
                NSLog("No envelope found. Something wrong with signal server?")
                return
            }

            switch envelope.type {
            case .ciphertext, .prekeyBundle:
                if self.decryptCiphertextEnvelope(envelope) {
                    var ackResponse = Signalservice_WebSocketResponseMessage()
                    ackResponse.status = 200
                    ackResponse.message = "OK"
                    ackResponse.id = message.request.id

                    var ackMessage = Signalservice_WebSocketMessage()
                    ackMessage.response = ackResponse
                    ackMessage.type = .response

                    //  self.delegate.sendSocketMessageAcknowledgement(ackMessage)
                }
            case .keyExchange, .unknown, .receipt:
                if DebugLevel.current == .verbose {
                    NSLog("Received unhandled evenlope of type: \(envelope.type)")
                }
            }
        } else {
            NSLog("Unsupported socket request: \(message.request)")
        }
    }

//    func handleReceiptEnvelope(_ envelope: Signalservice_Envelope) {
//        guard envelope.hasTimestamp else { return }
    //
//        let timestamp = envelope.timestamp
//        let messages: [IncomingSignalMessage] = self.store.messages(timestamp: timestamp, type: .incomingMessage)
//        guard !messages.isEmpty else {
//            NSLog("Missing message for delivery receipt %@.", String(describing: envelope))
//            return
//        }
    //
//        for message in messages {
//            message.isSent = true
//            try? self.store.save(message)
//        }
//    }

    private func receivedTextMessage(_ envelope: Signalservice_Envelope, dataMessage: Signalservice_DataMessage) {
        let groupIdData = dataMessage.hasGroup ? dataMessage.group.id : nil

        if let groupIdData = groupIdData, let groupId = String(data: groupIdData, encoding: .utf8) {
            self.handleGroupMessage(envelope: envelope, dataMessage: dataMessage, groupId: groupId)
        } else {
            self.handleMessage(envelope: envelope, dataMessage: dataMessage)
        }
    }

    private func handleStaleDevices(_ params: [String: Any], recipientAddress: String, completion: () -> Void) {
        defer { completion() }
        guard let staleDevices = params["staleDevices"] as? [Int32], !staleDevices.isEmpty else { return }

        for device in staleDevices {
            let address = SignalAddress(name: recipientAddress, deviceId: device)
            _ = self.signalContext.store.sessionStore.deleteSessionRecord(for: address)
        }
    }

    private func handleMismatchedDevices(_ params: [String: Any], recipientAddress: String, completion: () -> Void) {
        guard let extraDevices = params["extraDevices"] as? [Int32],
            let missingDevices = params["missingDevices"] as? [Int32] else {
            fatalError()
        }

        guard !extraDevices.isEmpty || !missingDevices.isEmpty else {
            NSLog("Error handling mismatched devices. No extra and no missing were found.")
            return
        }

        for device in extraDevices {
            let address = SignalAddress(name: recipientAddress, deviceId: device)
            _ = self.signalContext.store.sessionStore.deleteSessionRecord(for: address)
        }

        for device in missingDevices {
            NSLog("Should add device: %d to recipient: %@", device, recipientAddress)
        }

        completion()
    }

    private func handleMessage(envelope: Signalservice_Envelope, dataMessage: Signalservice_DataMessage, groupChat: SignalChat? = nil) {
        let timestamp = envelope.timestamp
        let body = dataMessage.body

        let chat: SignalChat
        if let groupChat = groupChat {
            chat = groupChat
        } else {
            chat = self.store.fetchOrCreateChat(with: envelope.source)
        }

        let incomingMessage = IncomingSignalMessage(body: body, chatId: chat.uniqueId, senderId: envelope.source, timestamp: timestamp, store: self.store)

        defer {
            try? self.store.save(incomingMessage)
        }

        guard !dataMessage.attachments.isEmpty else { return }

        let attachmentsProcessor = SignalServiceAttachmentsProcessor(attachments: dataMessage.attachments, message: incomingMessage, store: self.store, networkClient: self.networkClient)

        guard attachmentsProcessor.hasSupportedAttachments else {
            NSLog("Received unsupported media envelope")
            return
        }

        attachmentsProcessor.fetchAttachments()
    }

    private func handleGroupMessage(envelope: Signalservice_Envelope, dataMessage: Signalservice_DataMessage, groupId: String) {
        var newMembers = Set(dataMessage.group.members)
        let oldGroupChat = self.store.groupChat(groupId: groupId)

        if let groupChat = oldGroupChat {
            newMembers.formUnion(groupChat.recipientIdentifiers)
        }

        switch dataMessage.group.type {
        case .update:
            let newGroupChat = self.store.fetchOrCreateChat(groupId: groupId, members: Array(newMembers))
            let updateInfo = self.updateInfo(groupChat: newGroupChat, dataMessage: dataMessage)

            newGroupChat.name = dataMessage.group.name
            newGroupChat.recipientIdentifiers = Array(newMembers)

            do {
                try self.store.save(newGroupChat)

                // create info message informing of update
                let infoMessage = InfoSignalMessage(senderId: envelope.source, chatId: newGroupChat.uniqueId, messageType: .groupUpdate, customMessage: updateInfo.customMessage, additionalInfo: updateInfo.additionalInfo)

                try self.store.save(infoMessage)
            } catch (let error) {
                NSLog("Could not save new group chat. %@", error.localizedDescription)
            }
        case .quit:
            guard let oldGroupChat = oldGroupChat else {
                //                DebugLevel.current == .verbose {
                //                    NSLog("Ignoring quit group message from unknown group")
                //                }
                return
            }

            newMembers.remove(envelope.source)
            oldGroupChat.recipientIdentifiers = Array(newMembers)

            do {
                try self.store.save(oldGroupChat)
                let localizedGroupInfoString = NSLocalizedString("GROUP_MEMBER_LEFT", comment: "Displayed when a member leaves a group")
                let updateGroupInfoMessage = String(format: localizedGroupInfoString, envelope.source)

                let infoMessage = InfoSignalMessage(senderId: envelope.source, chatId: oldGroupChat.uniqueId, messageType: .groupQuit, customMessage: updateGroupInfoMessage, additionalInfo: oldGroupChat.contactsDelegate?.displayName(for: envelope.source))
                try self.store.save(infoMessage)
            } catch (let error) {
                NSLog("Could not save group chat. %@", error.localizedDescription)
            }
        case .deliver:
            guard let oldGroupChat = oldGroupChat else {
//                DebugLevel.current == .verbose {
//                    NSLog("Ignoring deliver group message from unknown group")
//                }
                return
            }

            self.handleMessage(envelope: envelope, dataMessage: dataMessage, groupChat: oldGroupChat)
        case .requestInfo:
            self.handleGroupInfoRequest(envelope: envelope, dataMessage: dataMessage, groupChat: oldGroupChat)
        default:
            NSLog("Ignoring message of type: \(dataMessage.group.type)")
        }
    }

    ///TODO: Fix group info requests. Should tell others about a group.
    private func handleGroupInfoRequest(envelope: Signalservice_Envelope, dataMessage: Signalservice_DataMessage, groupChat: SignalChat?) {
        guard let groupChat = groupChat else { return }
        /// Important: don't give info about a group if they don't belong to it.
        guard groupChat.recipientIdentifiers.contains(envelope.source) else { return }
        // Not sure when this would ever be the case. But Signal does it, so I'm leaving this here for now.
        // Probably if we leave the group, I assume.
        guard groupChat.recipientIdentifiers.contains(self.sender.username) else { return }

        let updateInfo = self.updateInfo(groupChat: groupChat, dataMessage: dataMessage)

        // create info message informing of update
        let infoMessage = OutgoingSignalMessage(recipientId: envelope.source, chatId: groupChat.uniqueId, body: updateInfo.customMessage, groupMessageType: .update, store: self.store)

        // Only send it to the requesting party.
        let recipient = SignalAddress(name: envelope.source, deviceId: Int32(envelope.sourceDevice))
        self.sendMessage(infoMessage, to: recipient, in: groupChat, shouldPersistMessage: false) { _ in }
    }

    private func handleEnvelope(_ envelope: Signalservice_Envelope, dataMessage: Signalservice_DataMessage) {
        if dataMessage.hasGroup {
            let groupContext = dataMessage.group
            guard let groupId = String(data: groupContext.id, encoding: .utf8) else { fatalError() }

            let chat = self.store.groupChat(groupId: groupId)

            if chat == nil {
                // Unknown group.
                switch groupContext.type {
                case .update:
                    // Accept group updates for unknown groups.
                    break
                case .deliver:
                    // send group info request, instead
                    self.sendGroupInfoRequest(groupId: groupId, envelope: envelope)
                    return
                default:
                    if DebugLevel.current == .verbose {
                        NSLog("Ignoring group message \(dataMessage)")
                    }
                    return
                }
            }
        }

        if let flags = Signalservice_DataMessage.Flags(rawValue: Int(dataMessage.flags)) {
            if flags == .endSession {
                // handle end session with envelope
            } else if flags == .expirationTimerUpdate {
                // handle expiration timer update with evenlope
            }
        }

        self.receivedTextMessage(envelope, dataMessage: dataMessage)
        let isGroupAvatarUpdate = dataMessage.hasGroup && dataMessage.group.type == .update && dataMessage.group.hasAvatar
        if isGroupAvatarUpdate {
            ///TODO: group avatar update
            //                DebugLevel.current == .verbose {
            //                    NSLog("Data message has group avatar attachment.")
            //                }

            // handleReceivedGroupAvatarUpdateWithEnvelope
        }
    }

    private func sendGroupInfoRequest(groupId: String, envelope: Signalservice_Envelope) {
        let recipient = SignalAddress(name: envelope.source, deviceId: Int32(envelope.sourceDevice))
        let newGroupChat = self.store.fetchOrCreateChat(groupId: groupId, members: [recipient.name, self.sender.username])
        let syncGroupRequestMessage = SyncGroupRequestSignalMessage(for: newGroupChat, store: self.store)

        self.sendMessage(syncGroupRequestMessage, to: recipient, in: newGroupChat) { success in
            if success {
                NSLog("Sent group info request to %@", recipient.name)
            }
        }
    }

    private func decryptCiphertextEnvelope(_ envelope: Signalservice_Envelope) -> Bool {
        let content = envelope.hasContent ? envelope.content : envelope.legacyMessage

        let senderAddress = SignalAddress(name: envelope.source, deviceId: Int32(envelope.sourceDevice))

        let sessionCipher = SignalSessionCipher(address: senderAddress, context: self.signalContext)

        var cipherMessage: SignalLibraryMessage
        do {
            cipherMessage = try self.cipherMessage(from: content)
        } catch (let error) {
            NSLog("Could not decrypt message: %@", error.localizedDescription)

            return false
        }

        if cipherMessage is SignalLibraryPreKeyMessage {
            self.networkClient.checkPreKeys(in: self.signalContext, sender: self.sender)
        }

        do {
            guard let decryptedData = try sessionCipher.decrypt(cipher: cipherMessage),
                let content = try? Signalservice_Content(serializedData: decryptedData) else {
                NSLog("Could not decrypt message! (1)")
                return false
            }

            if content.hasSyncMessage {
                // ignored for now
                // print(self.store.messages(timestamp: envelope.timestamp, type: .incomingMessage))
                // self.handleReceiptEnvelope(envelope)
            } else if content.hasCallMessage {
                // we don't support calls
            } else if content.hasDataMessage {
                self.handleEnvelope(envelope, dataMessage: content.dataMessage)
            } else {
                NSLog("Error: unknown content: \(content)")
            }

        } catch (let error) {
            NSLog("Could not decrypt message: %@", error.localizedDescription)
            return false
        }

        return true
    }

    private func deviceMessage(_ message: OutgoingSignalMessage, to address: SignalAddress, in chat: SignalChat) -> [[String: Any]] {
        let dispatchSemaphore = DispatchSemaphore(value: 0)

        if !self.signalContext.store.sessionStore.sessionRecordExists(for: address) {
            var pkBundle: SignalPreKeyBundle?

            self.networkClient.fetchPreKeyBundle(for: address.name) { preKeyBundle in
                pkBundle = preKeyBundle

                dispatchSemaphore.signal()
            }

            _ = dispatchSemaphore.wait(timeout: .distantFuture)

            let sessionBuilder = SignalSessionBuilder(address: address, context: self.signalContext)

            guard let bundle = pkBundle, sessionBuilder.processPreKeyBundle(bundle) else {
                NSLog("Could not process prekey bundle!")
                return []
            }
        }

        let sessionCipher = SignalSessionCipher(address: address, context: self.signalContext)

        let sessionRecordData = self.signalContext.store.sessionStore.sessionRecord(for: address)
        let sessionRecord = SessionRecord(data: sessionRecordData, signalContext: self.signalContext)
        let remoteRegistrationId = sessionRecord.remoteRegistrationId

        let ciphertext: SignalCiphertext
        do {
            ciphertext = try sessionCipher.encrypt(message: message, in: chat)
        } catch (let error) {
            fatalError("Could not encrypt ciphertext: \(error.localizedDescription)")
        }

        return [[
            "type": OutgoingSignalMessage.MessageType(ciphertext.ciphertextType).rawValue,
            "destination": address.name,
            "destinationDeviceId": address.deviceId,
            "destinationRegistrationId": remoteRegistrationId,
            "content": ciphertext.base64Encoded(),
            "isSilent": false
        ]]
    }

    private func cipherMessage(from data: Data, ciphertextType: CiphertextType = .unknown) throws -> SignalLibraryMessage {
        var message: SignalLibraryCiphertextMessage?
        var preKeyMessage: SignalLibraryPreKeyMessage?

        if ciphertextType == .preKeyMessage {
            preKeyMessage = SignalLibraryPreKeyMessage(data: data, context: self.signalContext)
            if preKeyMessage == nil {
                throw ErrorFromSignalError(.invalidArgument)
            }
        } else if ciphertextType == .message {
            message = SignalLibraryCiphertextMessage(data: data, context: self.signalContext)
            if message == nil {
                throw ErrorFromSignalError(.invalidArgument)
            }
        } else {
            // Fall back to brute force type detection...
            preKeyMessage = SignalLibraryPreKeyMessage(data: data, context: self.signalContext)
            message = SignalLibraryCiphertextMessage(data: data, context: self.signalContext)
            if preKeyMessage == nil && message == nil {
                throw ErrorFromSignalError(.invalidArgument)
            }
        }

        guard let cipherMessage: SignalLibraryMessage = (preKeyMessage ?? message)
            else { throw ErrorFromSignalError(.invalidArgument) }

        return cipherMessage
    }

    private func updateInfo(groupChat: SignalChat, dataMessage: Signalservice_DataMessage) -> (customMessage: String, additionalInfo: String) {
        // new group
        if groupChat.recipients == nil || groupChat.recipients?.count == 0 {
            return ("GROUP_BECAME_MEMBER", groupChat.name)
        }

        // name changed
        if groupChat.name != dataMessage.group.name && groupChat.name != String(data: dataMessage.group.id, encoding: .utf8) {
            return ("GROUP_TITLE_CHANGED", dataMessage.group.name)
        }

        ///TODO:  group image changed
        //        if dataMessage.group.avatar.id != newGroup.avatarId {
        //            return (NSLocalizedString("GROUP_AVATAR_CHANGED", comment: "Displays a message indicating the group has a new image"),
        //            dataMessage.group.avatar.id.description)
        //        }

        // Changed members
        var customMessage = "GROUP_UPDATED"
        var infoMessage = ""

        let oldMembers = Set(groupChat.recipientIdentifiers)
        let newMembers = Set(dataMessage.group.members)

        let joiningMembers = newMembers.subtracting(oldMembers)
        let leavingMembers = oldMembers.subtracting(newMembers)

        if !joiningMembers.isEmpty {
            infoMessage.append(joiningMembers.joined(separator: ", "))
            customMessage.append("GROUP_MEMBER_JOINED")
        }

        if !leavingMembers.isEmpty {
            infoMessage.append(leavingMembers.joined(separator: ", "))
            customMessage.append("GROUP_MEMBER_LEFT")
        }

        return (customMessage, infoMessage)
    }
}
