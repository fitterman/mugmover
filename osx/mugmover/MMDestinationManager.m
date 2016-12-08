//
//  MMDestinationManager.m
//  mugmover
//
//  Created by Bob Fitterman on 4/28/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMPhotoLibrary.h"
#import "MMPrefsManager.h"
#import "MMDestinationManager.h"
#import "MMDestinationSmugmug.h"
#import "MMWindowController.h"

NSInteger const maxSupportedDestinations = 50;

@implementation MMDestinationManager

- (id) initForWindowController: (id) windowController
{
    self = [super init];
    if (self)
    {
        _windowController = windowController;
        _destinations = [[NSMutableArray alloc] initWithCapacity: maxSupportedDestinations];
        [MMPrefsManager deserializeDestinationsFromDefaultsMergingIntoMutableArray: _destinations];
    }
    return self;
}

- (BOOL) isAtCapacity
{
    return [self totalDestinations] >= maxSupportedDestinations;
}

/**
 * Attempts to add a new destination object to the array. Sets the +error+ parameter if
 * an error occurs. Returns -1 if an error occurs, otherwise returns the index of the
 * newly-added value in the sorted array.
 */
- (NSInteger) insertDestination: (MMDestinationAbstract *) newDestination
                          error: (NSError **) error;
{
    if ([self isAtCapacity])
    {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Unable to add more destinations.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"The capacity has been exceeded.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Consider removing a destination and then adding this one.", nil)
                                   };
        *error = [NSError errorWithDomain: [[NSBundle mainBundle] bundleIdentifier]
                                     code: -59
                                 userInfo: userInfo];
        return -1; // No more room
    }
    for (MMDestinationAbstract *destination in _destinations)
    {
        if ([destination isEqualTo: newDestination])
        {
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: NSLocalizedString(@"The destination is already in the list.", nil),
                                       NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"The destination is already in the list.", nil),
                                       NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Check that you selected the correct destination.", nil)
                                       };
            *error = [NSError errorWithDomain: [[NSBundle mainBundle] bundleIdentifier]
                                         code: -58
                                     userInfo: userInfo];
            return -1;
        }
    }
    [_destinations addObject: newDestination];

    [MMPrefsManager storeToken: [newDestination oauthAccessToken]
                        secret: [newDestination oauthTokenSecret]
                forDestination: [newDestination identifier]
                      uniqueId: newDestination.uniqueId];
    [MMPrefsManager serializeDestinationsToDefaults: _destinations];
    return [self totalDestinations] - 1;
}

/**
 * Removes the destination entry at a particular index
 */
- (void) removeDestinationAtIndex: (NSUInteger) index
{
    [_destinations removeObjectAtIndex: index];
    [MMPrefsManager serializeDestinationsToDefaults: _destinations];
}

- (MMDestinationSmugmug *) destinationForIndex: (NSInteger) index
{
    if ((0 <= index) && (index < _destinations.count))
    {
        return [_destinations objectAtIndex: index];
    }
    else
    {
        return nil;
    }
}

- (NSString *) destinationNameForIndex: (NSInteger) index
{
    MMDestinationSmugmug *service = [self destinationForIndex: index];
    if (service)
    {
        return [service name];
    }
    else
    {
        return @"(none)";
    }
}

- (NSInteger) totalDestinations
{
    return [_destinations count];
}

@end
