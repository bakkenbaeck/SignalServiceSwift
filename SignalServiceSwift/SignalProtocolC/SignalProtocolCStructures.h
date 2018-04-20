//
//  SignalProtocolCStructures.swift
//  SignalServiceSwift
//
//  Created by Igor Ranieri on 17.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

#import "signal_protocol.h"
#import "signal_protocol_types.h"
#import "device_consistency.h"
#import "fingerprint.h"
#import "group_cipher.h"
#import "group_session_builder.h"
#import "hkdf.h"
#import "key_helper.h"
#import "protocol.h"
#import "sender_key.h"
#import "sender_key_state.h"
#import "session_builder.h"
#import "session_cipher.h"
#import "session_state.h"
#import "utarray.h"
#import "key_helper.h"

#import "signal_protocol_internal.h"

/* returns 0 on success */
int curve25519_sign(unsigned char* signature_out, /* 64 bytes */
    const unsigned char* curve25519_privkey, /* 32 bytes */
    const unsigned char* msg, const unsigned long msg_len, /* <= 256 bytes */
    const unsigned char* random); /* 64 bytes */

extern int curve25519_donna(uint8_t *, const uint8_t *, const uint8_t *);

/*
 Redefine private structures so they're visible in Swift
 */

#define DJB_TYPE 0x05
#define DJB_KEY_LEN 32
#define VRF_VERIFY_LEN 32

struct ec_public_key
{
    signal_type_base base;
    uint8_t data[DJB_KEY_LEN];
};

struct ec_private_key
{
    signal_type_base base;
    uint8_t data[DJB_KEY_LEN];
};

struct ec_key_pair
{
    signal_type_base base;
    ec_public_key *public_key;
    ec_private_key *private_key;
};

struct ec_public_key_list
{
    UT_array *values;
};

struct signal_protocol_store_context {
    signal_context *global_context;
    signal_protocol_session_store session_store;
    signal_protocol_pre_key_store pre_key_store;
    signal_protocol_signed_pre_key_store signed_pre_key_store;
    signal_protocol_identity_key_store identity_key_store;
    signal_protocol_sender_key_store sender_key_store;
};

struct ratchet_identity_key_pair {
    signal_type_base base;
    ec_public_key *public_key;
    ec_private_key *private_key;
};

struct session_pre_key {
    signal_type_base base;
    uint32_t id;
    ec_key_pair *key_pair;
};

struct session_signed_pre_key {
    signal_type_base base;
    uint32_t id;
    ec_key_pair *key_pair;
    uint64_t timestamp;
    size_t signature_len;
    uint8_t signature[];
};

struct session_pre_key_bundle {
    signal_type_base base;
    uint32_t registration_id;
    int device_id;
    uint32_t pre_key_id;
    ec_public_key *pre_key_public;
    uint32_t signed_pre_key_id;
    ec_public_key *signed_pre_key_public;
    signal_buffer *signed_pre_key_signature;
    ec_public_key *identity_key;
};

struct signal_protocol_key_helper_pre_key_list_node {
    session_pre_key *element;
    struct signal_protocol_key_helper_pre_key_list_node *next;
};

struct session_builder {
    signal_protocol_store_context *store;
    const signal_protocol_address *remote_address;
    signal_context *global_context;
};

struct session_cipher
{
    signal_protocol_store_context *store;
    const signal_protocol_address *remote_address;
    session_builder *builder;
    signal_context *global_context;
    int (*decrypt_callback)(session_cipher *cipher, signal_buffer *plaintext, void *decrypt_context);
    int inside_callback;
    void *user_data;
};

struct ciphertext_message
{
    signal_type_base base;
    int message_type;
    signal_context *global_context;
    signal_buffer *serialized;
};


struct signal_message
{
    ciphertext_message base_message;
    uint8_t message_version;
    ec_public_key *sender_ratchet_key;
    uint32_t counter;
    uint32_t previous_counter;
    signal_buffer *ciphertext;
};

struct pre_key_signal_message
{
    ciphertext_message base_message;
    uint8_t version;
    uint32_t registration_id;
    int has_pre_key_id;
    uint32_t pre_key_id;
    uint32_t signed_pre_key_id;
    ec_public_key *base_key;
    ec_public_key *identity_key;
    signal_message *message;
};

struct sender_key_message
{
    ciphertext_message base_message;
    uint8_t message_version;
    uint32_t key_id;
    uint32_t iteration;
    signal_buffer *ciphertext;
};

struct sender_key_distribution_message
{
    ciphertext_message base_message;
    uint32_t id;
    uint32_t iteration;
    signal_buffer *chain_key;
    ec_public_key *signature_key;
};

struct ratchet_root_key {
    signal_type_base base;
    signal_context *global_context;
    hkdf_context *kdf;
    uint8_t *key;
    size_t key_len;
};

typedef struct session_pending_key_exchange
{
    uint32_t sequence;
    ec_key_pair *local_base_key;
    ec_key_pair *local_ratchet_key;
    ratchet_identity_key_pair *local_identity_key;
} session_pending_key_exchange;

typedef struct message_keys_node
{
    ratchet_message_keys message_key;
    struct message_keys_node *prev, *next;
} message_keys_node;

typedef struct session_state_sender_chain
{
    ec_key_pair *sender_ratchet_key_pair;
    ratchet_chain_key *chain_key;
} session_state_sender_chain;

typedef struct session_state_receiver_chain
{
    ec_public_key *sender_ratchet_key;
    ratchet_chain_key *chain_key;
    message_keys_node *message_keys_head;
    struct session_state_receiver_chain *prev, *next;
} session_state_receiver_chain;

typedef struct session_pending_pre_key
{
    int has_pre_key_id;
    uint32_t pre_key_id;
    uint32_t signed_pre_key_id;
    ec_public_key *base_key;
} session_pending_pre_key;

struct session_state
{
    signal_type_base base;

    uint32_t session_version;
    ec_public_key *local_identity_public;
    ec_public_key *remote_identity_public;

    ratchet_root_key *root_key;
    uint32_t previous_counter;

    int has_sender_chain;
    session_state_sender_chain sender_chain;

    session_state_receiver_chain *receiver_chain_head;

    int has_pending_key_exchange;
    session_pending_key_exchange pending_key_exchange;

    int has_pending_pre_key;
    session_pending_pre_key pending_pre_key;

    uint32_t remote_registration_id;
    uint32_t local_registration_id;

    int needs_refresh;
    ec_public_key *alice_base_key;

    signal_context *global_context;
};

struct session_record
{
    signal_type_base base;
    session_state *state;
    session_record_state_node *previous_states_head;
    int is_fresh;
    signal_buffer *user_record;
    signal_context *global_context;
};

//// debug
//
//typedef struct message_keys_node
//{
//    ratchet_message_keys message_key;
//    struct message_keys_node *prev, *next;
//} message_keys_node;
//
//typedef struct session_state_sender_chain
//{
//    ec_key_pair *sender_ratchet_key_pair;
//    ratchet_chain_key *chain_key;
//} session_state_sender_chain;
//
//typedef struct session_state_receiver_chain
//{
//    ec_public_key *sender_ratchet_key;
//    ratchet_chain_key *chain_key;
//    message_keys_node *message_keys_head;
//    struct session_state_receiver_chain *prev, *next;
//} session_state_receiver_chain;
//
//typedef struct session_pending_key_exchange
//{
//    uint32_t sequence;
//    ec_key_pair *local_base_key;
//    ec_key_pair *local_ratchet_key;
//    ratchet_identity_key_pair *local_identity_key;
//} session_pending_key_exchange;
//
//typedef struct session_pending_pre_key
//{
//    int has_pre_key_id;
//    uint32_t pre_key_id;
//    uint32_t signed_pre_key_id;
//    ec_public_key *base_key;
//} session_pending_pre_key;
//
//struct session_state
//{
//    signal_type_base base;
//
//    uint32_t session_version;
//    ec_public_key *local_identity_public;
//    ec_public_key *remote_identity_public;
//
//    ratchet_root_key *root_key;
//    uint32_t previous_counter;
//
//    int has_sender_chain;
//    session_state_sender_chain sender_chain;
//
//    session_state_receiver_chain *receiver_chain_head;
//
//    int has_pending_key_exchange;
//    session_pending_key_exchange pending_key_exchange;
//
//    int has_pending_pre_key;
//    session_pending_pre_key pending_pre_key;
//
//    uint32_t remote_registration_id;
//    uint32_t local_registration_id;
//
//    int needs_refresh;
//    ec_public_key *alice_base_key;
//
//    signal_context *global_context;
//};
////
