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
                  albumId: (NSString *) albumId
           replacementFor: (NSString *) replacementFor
                    title: (NSString *) title
                  caption: (NSString *) caption
                 keywords: (NSString *) keywords
                    error: (NSError  **) error;

@end
