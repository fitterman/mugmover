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
@property (strong)          MMSmugmug *                 serviceApi;
@property (weak)            MMMasterViewController *    viewController;

- (id) initForViewController: (id) viewController;

- (NSInteger) insertService: newService
                      error: (NSError **) error;

- (BOOL) isAtCapacity;

- (NSString *) serviceNameForIndex: (NSInteger) index;

- (void) removeServiceAtIndex: (NSUInteger) index;

- (NSInteger) totalServices;

@end
