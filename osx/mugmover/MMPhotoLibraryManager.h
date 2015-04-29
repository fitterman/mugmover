//
//  MMPhotoLibraryManager.h
//  mugmover
//
//  Created by Bob Fitterman on 4/20/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MMMasterViewController;

@interface MMPhotoLibraryManager : NSObject
@property (strong)          NSMutableArray *            libraries;
@property (weak)            MMMasterViewController *    viewController;

- (id) initForViewController: (id) viewController;

- (NSInteger) insertLibraryPath: newLibraryPath
                          error: (NSError **) error;

- (BOOL) isAtCapacity;

- (NSString *) libraryNameForIndex: (NSInteger) index;

- (NSString *) libraryPathForIndex: (NSInteger) index;

- (void) removeLibraryAtIndex: (NSUInteger) index;

- (NSInteger) totalLibraries;


@end
