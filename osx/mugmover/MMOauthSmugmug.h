//
//  MMOauthSmugmug.h
//  mugmover
//
//  Created by Bob Fitterman on 3/24/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MMOauthAbstract.h"

@interface MMOauthSmugmug : MMOauthAbstract

- (NSURLRequest *) upload: (NSString *) filePath
                 albumUid: (NSString *) albumUid // for example, @"4RTMrj"
                    title: (NSString *) title
                  caption: (NSString *) caption
                     tags: (NSArray *) tags;

@end
