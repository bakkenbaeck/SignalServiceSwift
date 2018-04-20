//
//  Data+Signal.swift
//  SignalWrapper
//
//  Created by Igor Ranieri on 06.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation

public extension Data {
    public static func generateSecureRandomData(count: Int) -> Data {
        var outData = Data(count: count)

        let result = outData.withUnsafeMutableBytes { mutableBytes in
            SecRandomCopyBytes(kSecRandomDefault, count, mutableBytes)
        }

        guard result == 0 else { fatalError("Failed to randomly generate and copy bytes for private key generation. SecRandomCopyBytes error code: (\(result)).") }

        return outData
    }

    public init?(base64EncodedWithoutPadding aString: String) {
        let padding = aString.count % 4
        var strResult = aString
        if padding != 0 {
            let charsToAdd: Int = 4 - padding
            for _ in 0..<charsToAdd {
                strResult.append("=")
            }
        }

        self.init(base64Encoded: strResult)
    }
}
