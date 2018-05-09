//
//  SignalProtocolStore.h
//  SignalWrapper
//
//  Created by Igor Ranieri on 22.03.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "signal_protocol_types.h"

NS_ASSUME_NONNULL_BEGIN

@protocol SignalLibraryStoreProtocol;
@protocol SignalSessionStoreProtocol;
@protocol SignalPreKeyStoreProtocol;
@protocol SignalSignedPreKeyStoreProtocol;
@protocol SignalIdentityKeyStoreProtocol;
@protocol SignalSenderKeyStoreProtocol;
@protocol SignalLibraryStoreDelegate;

/**
 Our bridge between objc/swift and the pure c signal library. Handles all the callbacks for storing/retrieving data.
 */
@interface SignalLibraryStoreBridge : NSObject

@property (nonatomic, strong, readonly) id<SignalSessionStoreProtocol> sessionStore;
@property (nonatomic, strong, readonly) id<SignalPreKeyStoreProtocol> preKeyStore;
@property (nonatomic, strong, readonly) id<SignalSignedPreKeyStoreProtocol> signedPreKeyStore;
@property (nonatomic, strong, readonly) id<SignalIdentityKeyStoreProtocol> identityKeyStore;
@property (nonatomic, strong, readonly) id<SignalSenderKeyStoreProtocol> senderKeyStore;
@property (nonatomic, readonly) signal_protocol_store_context *storeContextPointer;


- (instancetype) initWithSignalStore:(id<SignalLibraryStoreProtocol>)signalStore;

- (instancetype) initWithSessionStore:(id<SignalSessionStoreProtocol>)sessionStore
                          preKeyStore:(id<SignalPreKeyStoreProtocol>)preKeyStore
                    signedPreKeyStore:(id<SignalSignedPreKeyStoreProtocol>)signedPreKeyStore
                     identityKeyStore:(id<SignalIdentityKeyStoreProtocol>)identityKeyStore
                       senderKeyStore:(id<SignalSenderKeyStoreProtocol>)senderKeyStore;


- (void)setupWithContext:(signal_context *)context;

@end

NS_ASSUME_NONNULL_END
