//
//  SignalServiceStore.swift
//  SignalServiceSwift
//
//  Created by Igor Ranieri on 17.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation

public enum SignalServiceStoreChangeType {
    case insert
    case update
    case delete
}

public protocol SignalServiceStoreChatDelegate {
    func signalServiceStoreWillChangeChats()
    func signalServiceStoreDidChangeChat(_ chat: SignalChat, at indexPath: IndexPath, for changeType: SignalServiceStoreChangeType)
    func signalServiceStoreDidChangeChats()
}

public protocol SignalServiceStoreMessageDelegate {
    func signalServiceStoreWillChangeMessages()
    func signalServiceStoreDidChangeMessage(_ message: SignalMessage, at indexPath: IndexPath, for changeType: SignalServiceStoreChangeType)
    func signalServiceStoreDidChangeMessages()
}

public protocol SignalServiceStore {
    // Fetch data
    func messages(for chat: SignalChat) -> [SignalMessage]

    func chats() -> [SignalChat]

    func chat(recipientIdentifier: String) -> SignalChat?

    // Save data
    func save(message: SignalMessage)
    func save(chat: SignalChat)

    // Delete data
    func deleteAllChatsAndMessages()
}
