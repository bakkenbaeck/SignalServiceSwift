//
//  SessionRecord.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 12.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

/// Wrapper for a signal session_record.
@objc class SessionRecord: NSObject {
    var remoteRegistrationId: UInt32 {
        return self.sessionRecordPointer.pointee.state.pointee.remote_registration_id
    }

    var sessionRecordPointer: UnsafeMutablePointer<session_record>

    init(data: Data, signalContext: SignalContext) {
        let data = data as NSData

        var recordPointer: UnsafeMutablePointer<session_record>?

        guard session_record_deserialize(&recordPointer, data.bytes.assumingMemoryBound(to: UInt8.self), data.length, signalContext.context) >= 0,
            let record = recordPointer else {
            fatalError("Could not deserialize session record")
        }

        self.sessionRecordPointer = record

        super.init()
    }
}
