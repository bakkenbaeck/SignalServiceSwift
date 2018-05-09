//
//  User.swift
//  SQLiteDemo
//
//  Created by Igor Ranieri on 20.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import EtherealCereal
import Foundation
import SignalServiceSwift

class User: Codable {
    enum CodingKeys: String, CodingKey {
        case password
        case signalingKey
        case privateKey
    }

    var privateKey: String
    var password: String
    var signalingKey: String? = nil

    var preKeyBundle: SignalPreKeyBundle? = nil

    lazy var cereal: EtherealCereal = {
        EtherealCereal(privateKey: self.privateKey)
    }()

    lazy var address: SignalAddress = {
        SignalAddress(name: self.toshiAddress, deviceId: 1)
    }()

    lazy var toshiAddress: String = {
        self.cereal.address
    }()

    init(privateKey: String) {
        self.privateKey = privateKey

        self.password = UUID().uuidString
    }
}
