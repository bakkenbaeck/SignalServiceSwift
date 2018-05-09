//
//  SignalAddress.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 20.03.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

/// A receiving-end signal user.
///
/// This is the equivalent of a Contact. It stores a username and device id, that is used to identify to us
/// and the server who the recipient of a message is.
@objc public class SignalAddress: NSObject, Codable {
    @objc public let name: String
    @objc public let deviceId: Int32

    internal var nameForStoring: String {
        return "\(self.name):\(self.deviceId)"
    }

    enum CodingKeys: String, CodingKey {
        case name
        case deviceId
    }

    @objc var addressPointer: UnsafeMutablePointer<signal_protocol_address>

    @objc public init(name: String, deviceId: Int32) {
        self.name = name
        self.deviceId = deviceId

        guard let data = name.data(using: .utf8) else {
            fatalError()
        }

        let address = UnsafeMutablePointer<signal_protocol_address>.allocate(capacity: 1)
        address.pointee.name_len = data.count
        address.pointee.device_id = deviceId

        let bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
        data.copyBytes(to: bytes, count: data.count)
        bytes.withMemoryRebound(to: Int8.self, capacity: data.count) { pointer in
            address.pointee.name = UnsafePointer(pointer)
        }

        self.addressPointer = address

        super.init()
    }

    @objc public init?(with address: UnsafeMutablePointer<signal_protocol_address>) {
        // Due to the nature of C, sometimes the address.name pointer will go over the length of the C-string.
        // As a result, String(cString:encoding:) will return nil. If we ensure we're only using the valid array length
        // it will work, as the garbage data at the end will be ignored. Hence why Signal provides us with  both name and name_len.
        let data = Data(bytes: address.pointee.name, count: address.pointee.name_len)
        guard let name = String(data: data, encoding: .utf8) else {
            return nil
        }

        self.name = name
        self.deviceId = address.pointee.device_id
        self.addressPointer = address

        super.init()
    }

    public required convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(String.self, forKey: .name)
        let deviceId = try container.decode(Int32.self, forKey: .deviceId)

        self.init(name: name, deviceId: deviceId)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.deviceId, forKey: .deviceId)
    }

    deinit {
        signal_type_unref(UnsafeMutableRawPointer(self.addressPointer).assumingMemoryBound(to: signal_type_base.self))
    }
}
