//
//  MMServiceFileSystem.h
//  mugmover
//
//  Created by Bob Fitterman on 12/7/16.
//  Copyright © 2016 Dicentra LLC. All rights reserved.
//

#ifndef MMServiceFileSystem_h
#define MMServiceFileSystem_h

#import "MMServiceAbstract.h"

@class MMServiceFileSystem;

@interface MMServiceFileSystem : MMServiceAbstract

- (id) initFromDictionary: (NSDictionary *) dictionary;

@end
#endif /* MMServiceFileSystem_h */
