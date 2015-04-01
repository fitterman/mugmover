//
//  MMOauthFlickr.h
//  mugmover
//
//  Created by Bob Fitterman on 3/24/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MMOauthAbstract.h"

@interface MMOauthFlickr : MMOauthAbstract
@property (strong, readonly)    NSString *      interimTokenSecret;
@end

