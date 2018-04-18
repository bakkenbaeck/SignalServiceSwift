//
//  SignalContext.m
//  SignalProtocol-ObjC
//
//  Created by Chris Ballinger on 6/26/16.
//
//

#import "SignalContext.h"
#import "SignalCommonCryptoProvider.h"

static void swift_signal_lock(void *user_data);
static void swift_signal_unlock(void *user_data);
static void swift_signal_log(int level, const char *message, size_t len, void *user_data);

@interface SignalContext (Private)
@property (class, nonatomic, assign) SignalContext *shared;
@end

@implementation SignalContext
static SignalContext *_shared = nil;

+ (void)setShared:(SignalContext *)shared {
    _shared = shared;
}

+ (SignalContext *)shared {
    return _shared;
}

- (void)dealloc {
    if (_context) {
        signal_context_destroy(_context);
    }
}

- (instancetype)initWithStore:(SignalProtocolStore *)store {
    NSParameterAssert(store);

    if (self = [super init]) {
        int result = signal_context_create(&_context, (__bridge void *)(self));
        if (result != 0) {
            return nil;
        }
        
        // Setup crypto provider
        _commonCryptoProvider = [[SignalCommonCryptoProvider alloc] init];
        signal_crypto_provider cryptoProvider = [_commonCryptoProvider cryptoProvider];
        signal_context_set_crypto_provider(_context, &cryptoProvider);
        
        // Logs & Locking
        _lock = [[NSRecursiveLock alloc] init];
        signal_context_set_locking_functions(_context, swift_signal_lock, swift_signal_unlock);
        signal_context_set_log_function(_context, swift_signal_log);

        // Storage
        _store = store;

        [_store setupWithContext:_context];

        SignalContext.shared = self;
    }

    return self;
}

@end

static void swift_signal_lock(void *user_data) {
    SignalContext *context = (__bridge SignalContext *)(user_data);
    [context.lock lock];
}

static void swift_signal_unlock(void *user_data) {
    SignalContext *context = (__bridge SignalContext *)(user_data);
    [context.lock unlock];
}

static void swift_signal_log(int level, const char *message, size_t len, void *user_data) {
//#if DEBUG
    NSLog(@"SignalProtocol (%d): %@", level, [NSString stringWithUTF8String:message]);
//#endif
}
