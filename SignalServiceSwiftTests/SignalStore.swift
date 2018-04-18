//
//  SignalStore.swift
//  SignalServiceSwiftTests
//
//  Created by Igor Ranieri on 18.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation
import SignalServiceSwift

class SignalStore: SignalServiceStore {

    var numberOfChats: Int {
        return self.chats.count
    }

    var chatDelegate: SignalServiceStoreChatDelegate?
    var messageDelegate: SignalServiceStoreMessageDelegate?

    private var chats: [Data] = []
    private var messages: [Data] = []

    public func chat(at index: Int) -> SignalChat? {
        let chatData = self.chats[index]
        let chat = try? JSONDecoder().decode(SignalChat.self, from: chatData)

        return chat
    }

    func chat(recipientName: String) -> SignalChat? {
        //        for chat in self.chats where chat["recipient"] as? String == recipientName {
        //            return SignalChat(with: chat)
        //        }

        return nil
    }

    func chat(chatId: String) -> SignalChat? {
        //        for chat in self.chats where chat["uniqueId"] as? String == chatId {
        //            return SignalChat(with: chat)
        //        }

        return nil
    }

    func messages(in chat: SignalChat) -> [SignalMessage] {
        //        let messages = self.messages.compactMap({ message -> [String: Any]? in
        //            return (message["chatId"] as? String ?? "" == chat.uniqueId) ? message : nil
        //        }).sorted(by: { (a, b) -> Bool in
        //            return (a["timestamp"] as? UInt64 ?? 0) < (b["timestamp"] as? UInt64 ?? 0)
        //        }).map { messageDict -> SignalMessage in
        //            guard let className = messageDict["class"] as? String else { fatalError() }
        //
        //            if className.hasSuffix(String(describing: SignalOutgoingMessage.self)) {
        //                return SignalOutgoingMessage(with: messageDict, in: self)!
        //            } else if className.hasSuffix(String(describing: SignalIncomingMessage.self)) {
        //                return SignalIncomingMessage(with: messageDict, in: self)!
        //            } else {
        //                fatalError()
        //            }
        //        }

        return [] // messages
    }

    func save(message: SignalMessage) {
        self.messageDelegate?.signalServiceStoreWillChangeMessages()

        let data: Data
        if let message = message as? OutgoingSignalMessage {
            data = try! JSONEncoder().encode(message)
        } else if let message = message as? IncomingSignalMessage {
            data = try! JSONEncoder().encode(message)
        } else {
            fatalError("Add more cases as we add more message types…")
        }

        self.messages.append(data)
        let indexPath = IndexPath(item: self.messages.index(of: data)!, section: 0)
        self.messageDelegate?.signalServiceStoreDidChangeMessage(message, at: indexPath, for: .insert)

        self.messageDelegate?.signalServiceStoreDidChangeMessages()
    }

    func save(chat: SignalChat) {
        self.chatDelegate?.signalServiceStoreWillChangeChats()

        let data = try! JSONEncoder().encode(chat)
        self.chats.append(data)

        let indexPath = IndexPath(item: self.chats.index(of: data)!, section: 0)
        self.chatDelegate?.signalServiceStoreDidChangeChat(chat, at: indexPath, for: .insert)

        self.chatDelegate?.signalServiceStoreDidChangeChats()
    }

    func deleteAllChatsAndMessages() {
        self.chats = []
        self.messages = []
    }
}
