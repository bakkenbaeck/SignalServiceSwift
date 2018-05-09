//
//  SignalRecipientsDelegate.swift
//  SignalServiceSwift
//
//  Created by Igor Ranieri on 26.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

public protocol SignalRecipientsDelegate {
    func image(for address: String) -> UIImage?
    func displayName(for address: String) -> String
}
