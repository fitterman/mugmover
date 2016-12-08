//
//  MMServiceAbstract.m
//  mugmover
//
//  Created by Bob Fitterman on 12/7/16.
//  Copyright © 2016 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MMServiceAbstract.h"

@implementation MMServiceAbstract : NSObject ;

- (id) init
{
    self = [super init];
    if (self)
    {
        _uniqueId = nil;
        _errorLog = [[NSMutableArray alloc] init];
    }
    return self;
}

@end
