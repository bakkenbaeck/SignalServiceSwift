//
//  SignalContext.h
//  SignalProtocol-ObjC
//
//  Created by Chris Ballinger on 6/26/16.
//
//

@import Foundation;
#import "SignalCommonCryptoProvider.h"
#import "SignalLibraryStoreBridge.h"

@class SignalPreKey;
@class SignalKeyHelper;

NS_ASSUME_NONNULL_BEGIN

/**
 Our `signal_context` wrapper. This is needed by the signal library to point to all the external functions we use for cryptography and storage.
 */
@interface SignalContext : NSObject

/**
 Due to how the signal library is architectured, we need this as a singleton.
 */
@property (class, nonatomic, assign, readonly) SignalContext *shared;

/**
 Interfacing model for our vendored cryptographic functions.
 */
@property (nonnull, strong, readonly) SignalCommonCryptoProvider *commonCryptoProvider;


/**
 The C signal context we hold.
 */
@property (nonatomic, readonly) signal_context *context;


/**
 A recursive lock to ensure all cryptography is done serialised and not in parallel.
 */
@property (nonatomic, strong, readonly) NSRecursiveLock *lock;


/**
 See: SignalLibraryStoreBridge
 */
@property (nonatomic, strong, readonly) SignalLibraryStoreBridge *store;

/**
 See: SignalKeyHelper
 */
@property (nonatomic, strong) SignalKeyHelper *signalKeyHelper;

- (instancetype)initWithStore:(SignalLibraryStoreBridge *)store;

@end
NS_ASSUME_NONNULL_END
