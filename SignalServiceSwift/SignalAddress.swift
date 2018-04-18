//
//  SignalAddress.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 20.03.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation

@objc public class SignalAddress: NSObject {
    @objc public let name: String
    @objc public let deviceId: Int32

    @objc public var address: signal_protocol_address = signal_protocol_address.init()

    @objc public init(name: String, deviceId: Int32) {
        self.name = name
        self.deviceId = deviceId

        let cString = UnsafeMutablePointer<Int8>.allocate(capacity: name.lengthOfBytes(using: .utf8))

        self.name.withCString { c in
            cString.initialize(from: c, count: name.lengthOfBytes(using: .utf8))
        }

        self.address = signal_protocol_address(name: cString, name_len: self.name.lengthOfBytes(using: String.Encoding.utf8), device_id: deviceId)

        super.init()
    }

    @objc public convenience init?(with address: signal_protocol_address) {
        // Due to the nature of C, sometimes the address.name pointer will go over the length of the C-string.
        // As a result, String(cString:encoding:) will return nil. If we ensure we're only using the valid array length
        // it will work, as the garbage data at the end will be ignored. Hence why Signal provides us with  both name and name_len.
        let data = Data(bytes: address.name, count: address.name_len)
        guard let name = String(data: data, encoding: .utf8) else {
            return nil
        }

        self.init(name: name, deviceId: address.device_id)
    }

    deinit {
//        print("gone")
    }
}
