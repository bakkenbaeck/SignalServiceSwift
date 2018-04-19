//
//  IncomingSignalMessage.swift
//  SignalServiceSwift
//
//  Created by Igor Ranieri on 18.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation

public class IncomingSignalMessage: SignalMessage {
    public var isRead: Bool = false

    enum CodingKeys: String, CodingKey {
        case isRead
    }
    
    public init?(signalContentData data: Data, chatId: String) {
        guard let content = try? Signalservice_Content(serializedData: data) else {
            return nil
        }

        let dataMessage = content.dataMessage

        super.init(body: dataMessage.body, chatId: chatId)
    }

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.isRead = try container.decode(Bool.self, forKey: .isRead)

        try super.init(from: decoder)
    }
}
