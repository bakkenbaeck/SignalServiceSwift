//
//  Copyright (c) 2017 Open Whisper Systems. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (messagePadding)

- (NSData *)removePadding;

- (NSData *)paddedMessageBody;

- (BOOL)ows_constantTimeIsEqualToData:(NSData *)other;

@end
