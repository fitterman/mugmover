//
//  MMServiceManager.h
//  mugmover
//
//  Created by Bob Fitterman on 4/28/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MMMasterViewController;
@class MMSmugmug;

@interface MMServiceManager : NSObject

@property (strong)          NSMutableArray *            services;
@property (weak)            MMMasterViewController *    viewController;

- (id) initForViewController: (id) viewController;

- (NSInteger) insertService: newService
                      error: (NSError **) error;

- (BOOL) isAtCapacity;

- (void) removeServiceAtIndex: (NSUInteger) index;

- (MMSmugmug *) serviceForIndex: (NSInteger) index;

- (NSString *) serviceNameForIndex: (NSInteger) index;

- (NSInteger) totalServices;

@end
