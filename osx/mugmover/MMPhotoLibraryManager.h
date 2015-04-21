//
//  MMPhotoLibraryManager.h
//  mugmover
//
//  Created by Bob Fitterman on 4/20/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MMPhotoLibraryManager : NSObject
@property (strong)          NSMutableArray *            libraries;

- (id) init;

- (BOOL) insertLibraryPath: newLibraryPath
                     error: (NSError **) error;

- (BOOL) isAtCapacity;

- (NSString *) libraryNameForIndex: (NSInteger) index;

- (NSString *) libraryPathForIndex: (NSInteger) index;

- (NSInteger) totalLibraries;


@end
