//
//  SignalSender.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 09.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

public struct SignalSender: Codable {
    /// Works as a base-auth username, as well as an identifier.
    public var username: String

    /// Base-auth password.
    public var password: String

    /// This device id. If multiple device is supported, check against the server to avoid conflicts.
    public var deviceId: Int32

    /// Our remote unique id, it's changed if the user re-registers with the server.
    public var remoteRegistrationId: UInt32

    /// The signaling key, used to encrypt the envelopes we receive through the websocket.
    public let signalingKey: String

    public init(username: String, password: String, deviceId: Int32, remoteRegistrationId: UInt32, signalingKey: String) {
        self.username = username
        self.password = password
        self.deviceId = deviceId
        self.remoteRegistrationId = remoteRegistrationId
        self.signalingKey = signalingKey
    }
}
