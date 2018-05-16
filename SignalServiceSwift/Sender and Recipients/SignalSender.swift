//
//  SignalSender.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 09.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

struct SignalSender: Codable {
    /// Works as a base-auth username, as well as an identifier.
    var username: String

    /// Base-auth password.
    var password: String

    /// This device id. If multiple device is supported, check against the server to avoid conflicts.
    var deviceId: Int32

    /// Our remote unique id, it's changed if the user re-registers with the server.
    var remoteRegistrationId: UInt32

    /// The signaling key, used to encrypt the envelopes we receive through the websocket.
    let signalingKey: String
}
