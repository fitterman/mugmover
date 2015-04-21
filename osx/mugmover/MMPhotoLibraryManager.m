//
//  MMPhotoLibraryManager.m
//  mugmover
//
//  Created by Bob Fitterman on 4/20/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMPhotoLibrary.h"
#import "MMPhotoLibraryManager.h"

NSInteger const maxSupportedLibraries = 3;

@implementation MMPhotoLibraryManager

- (id) init
{
    self = [super init];
    if (self)
    {
        _libraries = [[NSMutableArray alloc] initWithCapacity: maxSupportedLibraries];
    }
    return self;
}

- (BOOL) isAtCapacity
{
    return [_libraries count] >= maxSupportedLibraries;
}

- (BOOL) insertLibraryPath: newLibraryPath
{
    if ([self isAtCapacity])
    {
        return NO; // No more room
    }
    for (NSString *libraryPath in _libraries)
    {
        if ([libraryPath isEqualTo: newLibraryPath])
        {
            return NO;
        }
    }
    [_libraries addObject: newLibraryPath];
    [_libraries sortUsingComparator: ^NSComparisonResult(NSString *libPath1, NSString *libPath2)
                                        {
                                            NSString *name1 = [MMPhotoLibrary nameFromPath: libPath1];
                                            NSString *name2 = [MMPhotoLibrary nameFromPath: libPath2];
                                            return  [name1 localizedCompare: name2];
                                        }];
    return YES;
}

- (NSString *) libraryNameForIndex: (NSInteger) index
{
    return [MMPhotoLibrary nameFromPath: [self libraryPathForIndex: index]];
}

- (NSString *) libraryPathForIndex: (NSInteger) index
{
    return [_libraries objectAtIndex: index];
}

- (NSInteger) totalLibraries
{
    return [_libraries count];
}


@end
;