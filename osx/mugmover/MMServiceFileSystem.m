//
//  MMServiceFileSystem.m
//  mugmover
//
//  Created by Bob Fitterman on 12/7/16.
//  Copyright © 2016 Dicentra LLC. All rights reserved.
//

#import "MMServiceAbstract.h"
#import "MMServiceFileSystem.h"

@implementation MMServiceFileSystem

- (id) initFromDictionary: (NSDictionary *) dictionary
{
    self = [super init];
    if ((self) &&
        (dictionary && [[dictionary valueForKey: @"type"] isEqualToString: @"filesystem"]))
    {
        self.uniqueId = [dictionary valueForKey: @"path"];
    }
    return self;
}

- (NSString *) identifier
{
    return @"filesystem";
}

- (NSString *) name
{
    return [NSString stringWithFormat: @"%@ (File System)\n%@", @"_handle", @"self.uniqueId"];
}

- (NSString *) oauthAccessToken
{
    return @"";
}

- (NSString *) oauthTokenSecret
{
    return @"";
}

@end
