//
//  NSData+messagePadding.m
//  TextSecureKit
//
//  Created by Frederic Jacobs on 15/11/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import "NSData+messagePadding.h"

@implementation NSData (messagePadding)

- (BOOL)ows_constantTimeIsEqualToData:(NSData *)other
{
    BOOL isEqual = YES;

    if (self.length != other.length) {
        return NO;
    }

    UInt8 *leftBytes = (UInt8 *)self.bytes;
    UInt8 *rightBytes = (UInt8 *)other.bytes;
    for (int i = 0; i < self.length; i++) {
        // rather than returning as soon as we find a discrepency, we compare the rest of
        // the byte stream to maintain a constant time comparison
        isEqual = isEqual && (leftBytes[i] == rightBytes[i]);
    }

    return isEqual;
}

- (NSData *)removePadding {
    unsigned long paddingStart = self.length;

    Byte data[self.length];
    [self getBytes:data length:self.length];

    for (long i = (long)self.length - 1; i >= 0; i--) {
        if (data[i] == (Byte)0x80) {
            paddingStart = (unsigned long)i;
            break;
        } else if (data[i] != (Byte)0x00) {
            return self;
        }
    }

    return [self subdataWithRange:NSMakeRange(0, paddingStart)];
}

- (NSData *)paddedMessageBody {
    // From
    // https://github.com/WhisperSystems/TextSecure/blob/master/libtextsecure/src/main/java/org/whispersystems/textsecure/internal/push/PushTransportDetails.java#L55
    // NOTE: This is dumb.  We have our own padding scheme, but so does the cipher.
    // The +1 -1 here is to make sure the Cipher has room to add one padding byte,
    // otherwise it'll add a full 16 extra bytes.

    NSUInteger paddedMessageLength = [self paddedMessageLength:(self.length + 1)] - 1;
    NSMutableData *paddedMessage   = [NSMutableData dataWithLength:paddedMessageLength];

    Byte paddingByte = 0x80;

    [paddedMessage replaceBytesInRange:NSMakeRange(0, self.length) withBytes:[self bytes]];
    [paddedMessage replaceBytesInRange:NSMakeRange(self.length, 1) withBytes:&paddingByte];

    return paddedMessage;
}

- (NSUInteger)paddedMessageLength:(NSUInteger)messageLength {
    NSUInteger messageLengthWithTerminator = messageLength + 1;
    NSUInteger messagePartCount            = messageLengthWithTerminator / 160;

    if (messageLengthWithTerminator % 160 != 0) {
        messagePartCount++;
    }

    return messagePartCount * 160;
}

@end
