//
//  MMDestinationFileSystem.h
//  mugmover
//
//  Created by Bob Fitterman on 12/7/16.
//  Copyright © 2016 Dicentra LLC. All rights reserved.
//

#ifndef MMDestinationFileSystem_h
#define MMDestinationFileSystem_h

#import "MMDestinationAbstract.h"

@class MMDestinationFileSystem;

@interface MMDestinationFileSystem : MMDestinationAbstract

@property (strong, readonly)    NSDictionary *          eventDictionary;

- (id) initFromDictionary: (NSDictionary *) dictionary;

@end
#endif /* MMDestinationFileSystem_h */
