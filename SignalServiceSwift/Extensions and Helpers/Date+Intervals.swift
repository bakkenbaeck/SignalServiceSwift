//
//  Date+Intervals.swift
//  SignalServiceSwift
//
//  Created by Igor Ranieri on 07.05.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation

extension Date {
    func daysSince(_ date: Date) -> Int {
        return Calendar.current.dateComponents([.day], from: self, to: date).day ?? 0
    }
}
