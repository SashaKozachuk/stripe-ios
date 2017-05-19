//
//  NSError+STPCustomerContext.h
//  Stripe
//
//  Created by Ben Guo on 5/18/17.
//  Copyright © 2017 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSError (STPCustomerContext)

+ (NSError *)stp_customerContextMissingKeyProviderError;

@end
