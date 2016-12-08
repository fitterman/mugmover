//
//  MMDestinationManager.h
//  mugmover
//
//  Created by Bob Fitterman on 4/28/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MMWindowController;
@class MMDestinationAbstract;
@class MMDestinationSmugmug;

@interface MMDestinationManager : NSObject

@property (strong)          NSMutableArray *        destinations;
@property (weak)            MMWindowController *    windowController;

- (id) initForWindowController: (id) windowController;

- (NSInteger) insertDestination: (MMDestinationAbstract *)newDestination
                          error: (NSError **) error;

- (BOOL) isAtCapacity;

- (void) removeDestinationAtIndex: (NSUInteger) index;

- (MMDestinationSmugmug *) destinationForIndex: (NSInteger) index;

- (NSString *) destinationNameForIndex: (NSInteger) index;

- (NSInteger) totalDestinations;

@end
