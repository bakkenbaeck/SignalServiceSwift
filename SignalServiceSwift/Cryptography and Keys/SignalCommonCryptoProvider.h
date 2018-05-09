//
//  SignalCommonCryptoProvider.h
//  Pods
//
//  Created by Chris Ballinger on 6/27/16.
//
//

@import Foundation;
#import "signal_protocol.h"

/**
 Our crypto provider, sets up all the external crypto functions required by signal.
 */
@interface SignalCommonCryptoProvider : NSObject

- (signal_crypto_provider)cryptoProvider;

@end


