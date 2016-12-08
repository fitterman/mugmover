//
//  MMServiceManager.h
//  mugmover
//
//  Created by Bob Fitterman on 4/28/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MMWindowController;
@class MMServiceSmugmug;

@interface MMServiceManager : NSObject

@property (strong)          NSMutableArray *            services;
@property (weak)            MMWindowController *    windowController;

- (id) initForWindowController: (id) windowController;

- (NSInteger) insertService: (MMServiceSmugmug *)newService
                      error: (NSError **) error;

- (BOOL) isAtCapacity;

- (void) removeServiceAtIndex: (NSUInteger) index;

- (MMServiceSmugmug *) serviceForIndex: (NSInteger) index;

- (NSString *) serviceNameForIndex: (NSInteger) index;

- (NSInteger) totalServices;

@end
