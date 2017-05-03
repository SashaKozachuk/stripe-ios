//
//  STPEphemeralKeyManager.m
//  Stripe
//
//  Created by Ben Guo on 5/9/17.
//  Copyright © 2017 Stripe, Inc. All rights reserved.
//

#import "STPEphemeralKeyManager.h"

#import "STPCustomerContext.h"
#import "STPEphemeralKey.h"
#import "StripeError.h"

static NSTimeInterval const DefaultExpirationInterval = 60;
static NSTimeInterval const MinEagerRefreshInterval = 60*60;

@interface STPEphemeralKeyManager ()
@property (nonatomic) STPEphemeralKey *customerKey;
@property (nonatomic) NSString *apiVersion;
@property (nonatomic, weak) id<STPEphemeralKeyProvider> keyProvider;
@property (nonatomic) NSDate *lastEagerKeyRefresh;
@end

@implementation STPEphemeralKeyManager

- (instancetype)initWithKeyProvider:(id<STPEphemeralKeyProvider>)keyProvider apiVersion:(NSString *)apiVersion {
    self = [super init];
    if (self) {
        _expirationInterval = DefaultExpirationInterval;
        _keyProvider = keyProvider;
        _apiVersion = apiVersion;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleWillForegroundNotification)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillEnterForegroundNotification
                                                  object:nil];
}

- (void)setExpirationInterval:(NSTimeInterval)expirationInterval {
    _expirationInterval = MIN(expirationInterval, 60*60);
}

- (BOOL)currentKeyIsUnexpired {
    return self.customerKey && self.customerKey.expires.timeIntervalSinceNow > self.expirationInterval;
}

// Eager key refreshes on app foreground are throttled to once per hour
- (BOOL)shouldPerformEagerRefresh {
    return !self.lastEagerKeyRefresh || self.lastEagerKeyRefresh.timeIntervalSinceNow > MinEagerRefreshInterval;
}

- (void)handleWillForegroundNotification {
    if (!self.currentKeyIsUnexpired && self.shouldPerformEagerRefresh) {
        self.lastEagerKeyRefresh = [NSDate date];
        [self.keyProvider createCustomerKeyWithAPIVersion:self.apiVersion completion:^(NSDictionary *jsonResponse, __unused NSError *error) {
            STPEphemeralKey *key = [STPEphemeralKey decodedObjectFromAPIResponse:jsonResponse];
            if (key) {
                self.customerKey = key;
            }
        }];
    }
}

- (void)getCustomerKey:(STPEphemeralKeyCompletionBlock)completion {
    if (self.currentKeyIsUnexpired) {
        completion(self.customerKey, nil);
    } else {
        [self.keyProvider createCustomerKeyWithAPIVersion:self.apiVersion completion:^(NSDictionary *jsonResponse, NSError *error) {
            STPEphemeralKey *key = [STPEphemeralKey decodedObjectFromAPIResponse:jsonResponse];
            if (key) {
                self.customerKey = key;
            }
            if (self.customerKey && self.customerKey.expires.timeIntervalSinceNow > 0) {
                completion(self.customerKey, nil);
            } else {
                completion(nil, error ?: [NSError stp_genericConnectionError]);
            }
        }];
    }
}

@end
