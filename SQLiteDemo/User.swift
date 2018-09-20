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
        case privateKey
    }

    var privateKey: String
    var password: String

    lazy var cereal: EtherealCereal = {
        EtherealCereal(privateKey: self.privateKey)
    }()

    lazy var address: SignalAddress = {
        SignalAddress(name: self.toshiAddress, deviceId: 1)
    }()

    lazy var toshiAddress: String = {
        self.cereal.address
    }()

    convenience init(privateKey: String) {
        self.init(privateKey: privateKey, password: UUID().uuidString)
    }

    init(privateKey: String, password: String) {
        self.privateKey = privateKey
        self.password = password
    }
}
