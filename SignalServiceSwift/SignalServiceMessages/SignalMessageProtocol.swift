//
//  SignalMessageProtocol.swift
//  SignalServiceSwift
//
//  Created by Igor Ranieri on 18.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation

public class SignalMessage: Codable {
    public var body: String
    public var chatId: String
    
    public var uniqueId: String = UUID().uuidString
    public var timestamp: TimeInterval = Date().timeIntervalSinceReferenceDate * 10000

    public init(body: String, chatId: String) {
        self.body = body
        self.chatId = chatId
    }
}
