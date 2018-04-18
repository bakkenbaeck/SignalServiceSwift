//
//  SignalRecipient.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 09.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation

public struct SignalRecipient: Codable {
    var name: String
    var deviceId: Int32
    var remoteRegistrationId: UInt32
}
