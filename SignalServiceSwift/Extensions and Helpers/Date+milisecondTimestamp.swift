//
//  Date+milisecondTimestamp.swift
//  SignalServiceSwift
//
//  Created by Igor Ranieri on 24.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

public extension Date {
    public var milisecondTimeIntervalSinceEpoch: UInt64 {
        return NSDate.ows_millisecondTimeStamp()
    }

    public init(milisecondTimeIntervalSinceEpoch timeInterval: UInt64) {
        self = NSDate.ows_date(withMillisecondsSince1970: timeInterval)
    }
}
