//
//  SignalContext.h
//  SignalProtocol-ObjC
//
//  Created by Chris Ballinger on 6/26/16.
//
//

@import Foundation;
#import "SignalCommonCryptoProvider.h"
#import "SignalProtocolStore.h"

NS_ASSUME_NONNULL_BEGIN
@interface SignalContext : NSObject

@property (class, nonatomic, assign, readonly) SignalContext *shared;

@property (nonnull, strong, readonly) SignalCommonCryptoProvider *commonCryptoProvider;
@property (nonatomic, readonly) signal_context *context;
@property (nonatomic, strong, readonly) NSRecursiveLock *lock;

@property (nonatomic, strong, readonly) SignalProtocolStore *store;

- (instancetype)initWithStore:(SignalProtocolStore *)store;

@end
NS_ASSUME_NONNULL_END
