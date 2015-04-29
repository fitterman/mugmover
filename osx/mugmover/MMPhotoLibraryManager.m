//
//  MMPhotoLibraryManager.m
//  mugmover
//
//  Created by Bob Fitterman on 4/20/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMPhotoLibrary.h"
#import "MMPhotoLibraryManager.h"

NSInteger const maxSupportedLibraries = 50;

@implementation MMPhotoLibraryManager

- (id) initForViewController: (id) viewController
{
    self = [super init];
    if (self)
    {
        _viewController = viewController;
        _libraries = [[NSMutableArray alloc] initWithCapacity: maxSupportedLibraries];
        [self deserializeFromDefaults];
    }
    return self;
}

- (BOOL) isAtCapacity
{
    return [self totalLibraries] >= maxSupportedLibraries;
}

/**
 * Attempts to add a new library path to the array. Sets the +error+ parameter if
 * an error occurs. Returns -1 if an error occurs, otherwise returns the index of the
 * newly-added value in the sorted array.
 */
- (NSInteger) insertLibraryPath: (NSString *) newLibraryPath
                          error: (NSError **) error;
{
    if ([self isAtCapacity])
    {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Unable to add more libraries.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"The capacity has been exceeded.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Consider removing one library and then adding this one.", nil)
                                   };
        *error = [NSError errorWithDomain: [[NSBundle mainBundle] bundleIdentifier]
                                     code: -57
                                 userInfo: userInfo];
        return -1; // No more room
    }
    for (NSString *libraryPath in _libraries)
    {
        if ([libraryPath isEqualTo: newLibraryPath])
        {
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: NSLocalizedString(@"The library is already in the list.", nil),
                                       NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"The library is already in the list.", nil),
                                       NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Check that you selected the correct library.", nil)
                                       };
            *error = [NSError errorWithDomain: [[NSBundle mainBundle] bundleIdentifier]
                                         code: -58
                                     userInfo: userInfo];
            return -1;
        }
    }
    [_libraries addObject: newLibraryPath];
    [_libraries sortUsingComparator: ^NSComparisonResult(NSString *libPath1, NSString *libPath2)
                                        {
                                            NSString *name1 = [MMPhotoLibrary nameFromPath: libPath1];
                                            NSString *name2 = [MMPhotoLibrary nameFromPath: libPath2];
                                            return  [name1 localizedCompare: name2];
                                        }];
    [self serializeToDefaults];
    return [_libraries indexOfObject: newLibraryPath];
}

/**
 * Removes the library entry at a particular index
 */
- (void) removeLibraryAtIndex: (NSUInteger) index
{
    [_libraries removeObjectAtIndex: index];
    [self serializeToDefaults];
}

- (void) serializeToDefaults
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject: _libraries forKey: @"libraries"];
    [defaults synchronize];
}

- (void) deserializeFromDefaults
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *array = [defaults objectForKey: @"libraries"];
    if (array)
    {
        [_libraries addObjectsFromArray: array];
    }
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