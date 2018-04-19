//
//  SignalProtocolStore.m
//  SignalWrapper
//
//  Created by Igor Ranieri on 22.03.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

#import "SignalLibraryStoreBridge.h"
#import <SignalServiceSwift/SignalServiceSwift-Swift.h>

static int load_session_func(signal_buffer **record, signal_buffer **user_record, const signal_protocol_address *address, void *user_data) {
    id sessionStore = (__bridge id<SignalSessionStoreProtocol>)(user_data);
    SignalAddress *addr = [[SignalAddress alloc] initWith:*address];
    NSData *data = nil;
    if (addr) {
        data = [sessionStore sessionRecordFor:addr];
    } else {
        return -1;
    }
    if (!data) {
        return 0;
    }
    signal_buffer *buffer = signal_buffer_create(data.bytes, data.length);
    *record = buffer;

    return 1;
}

static int get_sub_device_sessions_func(signal_int_list **sessions, const char *name, size_t name_len, void *user_data) {
    id <SignalSessionStoreProtocol> sessionStore = (__bridge id<SignalSessionStoreProtocol>)(user_data);
    NSString *addressName = [NSString stringWithUTF8String:name];
    NSArray<NSNumber*> *deviceIds = [sessionStore allDeviceIdsFor:addressName];
    signal_int_list *list = signal_int_list_alloc();
    if (!list) {
        return -1;
    }
    [deviceIds enumerateObjectsUsingBlock:^(NSNumber * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        signal_int_list_push_back(list, obj.intValue);
    }];
    *sessions = list;

    return (int)deviceIds.count;
}

static int store_session_func(const signal_protocol_address *address, uint8_t *record, size_t record_len, uint8_t *user_record, size_t user_record_len, void *user_data) {
    id <SignalSessionStoreProtocol> sessionStore = (__bridge id<SignalSessionStoreProtocol>)(user_data);
    SignalAddress *addr = [[SignalAddress alloc] initWith:*address];
    if (!addr) {
        return -1;
    }
    NSData *recordData = [NSData dataWithBytes:record length:record_len];
    BOOL result = [sessionStore storeSessionRecord:recordData for:addr];

    if (result) {
        return 0;
    } else {
        return -1;
    }
}

static int contains_session_func(const signal_protocol_address *address, void *user_data) {
    id <SignalSessionStoreProtocol> sessionStore = (__bridge id<SignalSessionStoreProtocol>)(user_data);
    SignalAddress *addr = [[SignalAddress alloc] initWith:*address];
    if (!addr) {
        return -1;
    }

    BOOL exists = [sessionStore sessionRecordExistsFor:addr];

    return exists;
}

static int delete_session_func(const signal_protocol_address *address, void *user_data) {
    id <SignalSessionStoreProtocol> sessionStore = (__bridge id<SignalSessionStoreProtocol>)(user_data);
    SignalAddress *addr = [[SignalAddress alloc] initWith:*address];
    if (!addr) {
        return -1;
    }
    BOOL wasDeleted = [sessionStore deleteSessionRecordFor:addr];

    return wasDeleted;
}

static int delete_all_sessions_func(const char *name, size_t name_len, void *user_data) {
    id <SignalSessionStoreProtocol> sessionStore = (__bridge id<SignalSessionStoreProtocol>)(user_data);
    int result = [sessionStore deleteAllSessionsFor:[NSString stringWithUTF8String:name]];

    return result;
}

static void destroy_func(void *user_data) {}

#pragma mark signal_protocol_pre_key_store

static int load_pre_key(signal_buffer **record, uint32_t pre_key_id, void *user_data) {
    id <SignalPreKeyStoreProtocol> preKeyStore = (__bridge id<SignalPreKeyStoreProtocol>)(user_data);
    NSData *preKey = [preKeyStore loadPreKeyWith:pre_key_id];

    if (!preKey) {
        return SG_ERR_INVALID_KEY_ID;
    }

    signal_buffer *buffer = signal_buffer_create(preKey.bytes, preKey.length);
    *record = buffer;

    return SG_SUCCESS;
}

static int store_pre_key(uint32_t pre_key_id, uint8_t *record, size_t record_len, void *user_data) {
    id <SignalPreKeyStoreProtocol> preKeyStore = (__bridge id<SignalPreKeyStoreProtocol>)(user_data);
    NSData *preKey = [NSData dataWithBytes:record length:record_len];
    BOOL success = [preKeyStore storePreKeyWithData:preKey id:pre_key_id];

    if (success) {
        return 0;
    } else {
        return -1;
    }
}

static int contains_pre_key(uint32_t pre_key_id, void *user_data) {
    id <SignalPreKeyStoreProtocol> preKeyStore = (__bridge id<SignalPreKeyStoreProtocol>)(user_data);
    BOOL containsPreKey = [preKeyStore containsPreKeyWith:pre_key_id];

    return containsPreKey;
}

static int remove_pre_key(uint32_t pre_key_id, void *user_data) {
    id <SignalPreKeyStoreProtocol> preKeyStore = (__bridge id<SignalPreKeyStoreProtocol>)(user_data);
    BOOL success = [preKeyStore deletePreKeyWith:pre_key_id];

    if (success) {
        return 0;
    } else {
        return -1;
    }
}

#pragma mark signal_protocol_signed_pre_key_store

static int load_signed_pre_key(signal_buffer **record, uint32_t signed_pre_key_id, void *user_data) {
    id <SignalSignedPreKeyStoreProtocol> signedPreKeyStore = (__bridge id<SignalSignedPreKeyStoreProtocol>)(user_data);
    NSData *key = [signedPreKeyStore loadSignedPreKeyWithId:signed_pre_key_id];

    if (!key) {
        return SG_ERR_INVALID_KEY_ID;
    }

    signal_buffer *buffer = signal_buffer_create(key.bytes, key.length);
    *record = buffer;

    return SG_SUCCESS;
}

static int store_signed_pre_key(uint32_t signed_pre_key_id, uint8_t *record, size_t record_len, void *user_data) {
    id <SignalSignedPreKeyStoreProtocol> signedPreKeyStore = (__bridge id<SignalSignedPreKeyStoreProtocol>)(user_data);
    NSData *key = [NSData dataWithBytes:record length:record_len];
    BOOL result = [signedPreKeyStore storeSignedPreKey:key signedPreKeyId:signed_pre_key_id];

    if (result) {
        return 0;
    } else {
        return -1;
    }
}

static int contains_signed_pre_key(uint32_t signed_pre_key_id, void *user_data) {
    id <SignalSignedPreKeyStoreProtocol> signedPreKeyStore = (__bridge id<SignalSignedPreKeyStoreProtocol>)(user_data);
    BOOL result = [signedPreKeyStore containsSignedPreKeyWithId:signed_pre_key_id];

    return result;
}

static int remove_signed_pre_key(uint32_t signed_pre_key_id, void *user_data) {
    id <SignalSignedPreKeyStoreProtocol> signedPreKeyStore = (__bridge id<SignalSignedPreKeyStoreProtocol>)(user_data);
    BOOL result = [signedPreKeyStore removeSignedPreKeyWithId:signed_pre_key_id];

    if (result) {
        return 0;
    } else {
        return -1;
    }
}

#pragma mark signal_protocol_identity_key_store

static int get_identity_key_pair(signal_buffer **public_data, signal_buffer **private_data, void *user_data) {
    id <SignalIdentityKeyStoreProtocol> identityKeyStore = (__bridge id<SignalIdentityKeyStoreProtocol>)(user_data);
    SignalIdentityKeyPair *keyPair = [identityKeyStore identityKeyPair];

    if (!keyPair) {
        return -1;
    }

    if (keyPair.publicKey) {
        signal_buffer *public = signal_buffer_create(keyPair.publicKey.bytes, keyPair.publicKey.length);
        *public_data = public;
    }
    if (keyPair.privateKey) {
        signal_buffer *private = signal_buffer_create(keyPair.privateKey.bytes, keyPair.privateKey.length);
        *private_data = private;
    }
    return 0;
}

static int get_local_registration_id(void *user_data, uint32_t *registration_id) {
    id <SignalIdentityKeyStoreProtocol> identityKeyStore = (__bridge id<SignalIdentityKeyStoreProtocol>)(user_data);
    uint32_t regId = [identityKeyStore localRegistrationId];

    if (regId > 0) {
        *registration_id = regId;
        return 0;
    } else {
        return -1;
    }
}

static int save_identity(const signal_protocol_address *_address, uint8_t *key_data, size_t key_len, void *user_data) {
    id <SignalIdentityKeyStoreProtocol> identityKeyStore = (__bridge id<SignalIdentityKeyStoreProtocol>)(user_data);
    SignalAddress *address = [[SignalAddress alloc] initWith:*_address];
    NSData *key = nil;

    if (key_data) {
        key = [NSData dataWithBytes:key_data length:key_len];
    }

    BOOL success = [identityKeyStore saveIdentityWith:address identityKey:key];

    if (success) {
        return 0;
    } else {
        return -1;
    }
}

static int swift_is_trusted_identity(const signal_protocol_address *_address, uint8_t *key_data, size_t key_len, void *user_data) {
    id <SignalIdentityKeyStoreProtocol> identityKeyStore = (__bridge id<SignalIdentityKeyStoreProtocol>)(user_data);

    SignalAddress *address = [[SignalAddress alloc] initWith:*_address];
    NSData *key = [NSData dataWithBytes:key_data length:key_len];
    BOOL isTrusted = [identityKeyStore isTrustedIdentityWith:address identityKey:key];

    return isTrusted;
}

#pragma mark signal_protocol_sender_key_store

static int swift_store_sender_key(const signal_protocol_sender_key_name *sender_key_name, uint8_t *record, size_t record_len, uint8_t *user_record, size_t user_record_len, void *user_data) {
    id <SignalSenderKeyStoreProtocol> senderKeyStore = (__bridge id<SignalSenderKeyStoreProtocol>)(user_data);
    SignalAddress *address = [[SignalAddress alloc] initWith:sender_key_name->sender];
    NSString *groupId = [NSString stringWithUTF8String:sender_key_name->group_id];
    NSData *key = [NSData dataWithBytes:record length:record_len];

    BOOL result = [senderKeyStore storeSenderKeyWith:key signalAddress:address groupId:groupId];

    if (result) {
        return 0;
    } else {
        return -1;
    }
}

static int swift_load_sender_key(signal_buffer **record, signal_buffer **user_record, const signal_protocol_sender_key_name *sender_key_name, void *user_data) {
    id <SignalSenderKeyStoreProtocol> senderKeyStore = (__bridge id<SignalSenderKeyStoreProtocol>)(user_data);
    SignalAddress *address = [[SignalAddress alloc] initWith:sender_key_name->sender];
    NSString *groupId = [NSString stringWithUTF8String:sender_key_name->group_id];
    NSData *key = [senderKeyStore loadSenderKeyFor:address groupId:groupId];

    if (key) {
        signal_buffer *buffer = signal_buffer_create(key.bytes, key.length);
        *record = buffer;
        return 1;
    } else {
        return 0;
    }
}

@implementation SignalLibraryStoreBridge

- (void) dealloc {
    if (_storeContextPointer) {
        signal_protocol_store_context_destroy(_storeContextPointer);
    }

    //_storeContext = NULL;
}

- (instancetype) initWithSignalStore:(id<SignalLibraryStoreProtocol>)signalStore {
    if (self = [self initWithSessionStore:signalStore preKeyStore:signalStore signedPreKeyStore:signalStore identityKeyStore:signalStore senderKeyStore:signalStore]){
    }
    return self;
}

- (instancetype)initWithSessionStore:(id<SignalSessionStoreProtocol>)sessionStore
                          preKeyStore:(id<SignalPreKeyStoreProtocol>)preKeyStore
                    signedPreKeyStore:(id<SignalSignedPreKeyStoreProtocol>)signedPreKeyStore
                     identityKeyStore:(id<SignalIdentityKeyStoreProtocol>)identityKeyStore
                       senderKeyStore:(id<SignalSenderKeyStoreProtocol>)senderKeyStore {


    if (self = [super init]) {
        _sessionStore = sessionStore;
        _preKeyStore = preKeyStore;
        _signedPreKeyStore = signedPreKeyStore;
        _identityKeyStore = identityKeyStore;
        _senderKeyStore = senderKeyStore;
    }
    return self;
}

- (void)setupWithContext:(signal_context*)context {
    NSParameterAssert(context != NULL);
    if (!context) {
        return;
    }

    signal_protocol_store_context_create(&_storeContextPointer, context);

    // Session Store
    signal_protocol_session_store sessionStoreCallbacks;
    sessionStoreCallbacks.load_session_func = load_session_func;
    sessionStoreCallbacks.get_sub_device_sessions_func = get_sub_device_sessions_func;
    sessionStoreCallbacks.store_session_func = store_session_func;
    sessionStoreCallbacks.contains_session_func = contains_session_func;
    sessionStoreCallbacks.delete_session_func = delete_session_func;
    sessionStoreCallbacks.delete_all_sessions_func = delete_all_sessions_func;
    sessionStoreCallbacks.destroy_func = destroy_func;
    sessionStoreCallbacks.user_data = (__bridge void *)(_sessionStore);
    signal_protocol_store_context_set_session_store(_storeContextPointer, &sessionStoreCallbacks);

    // PreKey store
    signal_protocol_pre_key_store preKeyStoreCallbacks;
    preKeyStoreCallbacks.load_pre_key = load_pre_key;
    preKeyStoreCallbacks.store_pre_key = store_pre_key;
    preKeyStoreCallbacks.contains_pre_key = contains_pre_key;
    preKeyStoreCallbacks.remove_pre_key = remove_pre_key;
    preKeyStoreCallbacks.destroy_func = destroy_func;
    preKeyStoreCallbacks.user_data = (__bridge void *)(_preKeyStore);
    signal_protocol_store_context_set_pre_key_store(_storeContextPointer, &preKeyStoreCallbacks);

    // Signed PreKey Store
    signal_protocol_signed_pre_key_store signedPreKeyStoreCallbacks;
    signedPreKeyStoreCallbacks.load_signed_pre_key = load_signed_pre_key;
    signedPreKeyStoreCallbacks.store_signed_pre_key = store_signed_pre_key;
    signedPreKeyStoreCallbacks.contains_signed_pre_key = contains_signed_pre_key;
    signedPreKeyStoreCallbacks.remove_signed_pre_key = remove_signed_pre_key;
    signedPreKeyStoreCallbacks.destroy_func = destroy_func;
    signedPreKeyStoreCallbacks.user_data = (__bridge void *)(_signedPreKeyStore);
    signal_protocol_store_context_set_signed_pre_key_store(_storeContextPointer, &signedPreKeyStoreCallbacks);

    // Identity Key Store
    signal_protocol_identity_key_store identityKeyStoreCallbacks;
    identityKeyStoreCallbacks.get_identity_key_pair = get_identity_key_pair;
    identityKeyStoreCallbacks.get_local_registration_id = get_local_registration_id;
    identityKeyStoreCallbacks.save_identity = save_identity;
    identityKeyStoreCallbacks.is_trusted_identity = swift_is_trusted_identity;
    identityKeyStoreCallbacks.destroy_func = destroy_func;
    identityKeyStoreCallbacks.user_data = (__bridge void *)(_identityKeyStore);
    signal_protocol_store_context_set_identity_key_store(_storeContextPointer, &identityKeyStoreCallbacks);

    // Sender Key Store
    signal_protocol_sender_key_store senderKeyStoreCallbacks;
    senderKeyStoreCallbacks.store_sender_key = swift_store_sender_key;
    senderKeyStoreCallbacks.load_sender_key = swift_load_sender_key;
    senderKeyStoreCallbacks.destroy_func = destroy_func;
    identityKeyStoreCallbacks.user_data = (__bridge void *)(_senderKeyStore);
    signal_protocol_store_context_set_sender_key_store(_storeContextPointer, &senderKeyStoreCallbacks);
}

@end
