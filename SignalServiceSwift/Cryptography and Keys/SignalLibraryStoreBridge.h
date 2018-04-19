//
//  SignalProtocolStore.h
//  SignalWrapper
//
//  Created by Igor Ranieri on 22.03.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "signal_protocol_types.h"

static int load_session_func(signal_buffer **record, signal_buffer **user_record, const signal_protocol_address *address, void *user_data);
static int get_sub_device_sessions_func(signal_int_list **sessions, const char *name, size_t name_len, void *user_data);
static int store_session_func(const signal_protocol_address *address, uint8_t *record, size_t record_len, uint8_t *user_record, size_t user_record_len, void *user_data);
static int contains_session_func(const signal_protocol_address *address, void *user_data);
static int delete_session_func(const signal_protocol_address *address, void *user_data);
static int delete_all_sessions_func(const char *name, size_t name_len, void *user_data);
static void destroy_func(void *user_data);

static int load_pre_key(signal_buffer **record, uint32_t pre_key_id, void *user_data);
static int store_pre_key(uint32_t pre_key_id, uint8_t *record, size_t record_len, void *user_data);
static int contains_pre_key(uint32_t pre_key_id, void *user_data);
static int remove_pre_key(uint32_t pre_key_id, void *user_data);

static int load_signed_pre_key(signal_buffer **record, uint32_t signed_pre_key_id, void *user_data);
static int store_signed_pre_key(uint32_t signed_pre_key_id, uint8_t *record, size_t record_len, void *user_data);
static int contains_signed_pre_key(uint32_t signed_pre_key_id, void *user_data);
static int remove_signed_pre_key(uint32_t signed_pre_key_id, void *user_data);

static int get_identity_key_pair(signal_buffer **public_data, signal_buffer **private_data, void *user_data);
static int get_local_registration_id(void *user_data, uint32_t *registration_id);
static int save_identity(const signal_protocol_address *_address, uint8_t *key_data, size_t key_len, void *user_data);
static int swift_is_trusted_identity(const signal_protocol_address *_address, uint8_t *key_data, size_t key_len, void *user_data);
static int swift_store_sender_key(const signal_protocol_sender_key_name *sender_key_name, uint8_t *record, size_t record_len, uint8_t *user_record, size_t user_record_len, void *user_data);

static int swift_load_sender_key(signal_buffer **record, signal_buffer **user_record, const signal_protocol_sender_key_name *sender_key_name, void *user_data);

NS_ASSUME_NONNULL_BEGIN

@protocol SignalSessionStoreProtocol;
@protocol SignalPreKeyStoreProtocol;
@protocol SignalSignedPreKeyStoreProtocol;
@protocol SignalIdentityKeyStoreProtocol;
@protocol SignalSenderKeyStoreProtocol;

@protocol SignalLibraryStoreProtocol <SignalSessionStoreProtocol, SignalPreKeyStoreProtocol, SignalSignedPreKeyStoreProtocol, SignalIdentityKeyStoreProtocol, SignalSenderKeyStoreProtocol>

-  (NSMutableDictionary * _Nullable) deviceSessionRecordsForAddressName:(NSString *)addressName;

@end

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
