//
//  SessionRecord.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 12.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation

public class SessionRecord {
    public var remoteRegistrationId: UInt32 {
        return self.sessionRecordPointer.pointee.state.pointee.remote_registration_id
    }

    var sessionRecordPointer: UnsafeMutablePointer<session_record>

    public init?(data: Data, signalContext: SignalContext) {
        guard let data = data as NSData? else { return nil }

        var recordPointer: UnsafeMutablePointer<session_record>? = nil

        guard session_record_deserialize(&recordPointer, data.bytes.assumingMemoryBound(to: UInt8.self), data.length, signalContext.context) >= 0,
            let record = recordPointer else {
                print("Could not deserialize session record")
                return nil
        }

        self.sessionRecordPointer = record
    }
}
