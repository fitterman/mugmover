//
//  MMServiceManager.m
//  mugmover
//
//  Created by Bob Fitterman on 4/28/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMServiceManager.h"
#import "MMSmugmug.h"

NSInteger const maxSupportedServices = 50;

@implementation MMServiceManager

- (id) init
{
    self = [super init];
    if (self)
    {
        _services = [[NSMutableArray alloc] initWithCapacity: maxSupportedServices];
    }
    return self;
}

- (BOOL) isAtCapacity
{
    return [self totalServices] >= maxSupportedServices;
}

/**
 * Attempts to add a new service path to the array. Sets the +error+ parameter if
 * an error occurs. Returns -1 if an error occurs, otherwise returns the index of the
 * newly-added value in the sorted array.
 */
- (NSInteger) insertService: (MMSmugmug *) newService
                      error: (NSError **) error;
{
    if ([self isAtCapacity])
    {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Unable to add more services.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"The capacity has been exceeded.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Consider removing one service and then adding this one.", nil)
                                   };
        *error = [NSError errorWithDomain: [[NSBundle mainBundle] bundleIdentifier]
                                     code: -59
                                 userInfo: userInfo];
        return -1; // No more room
    }
    for (MMSmugmug *service in _services)
    {
        if ([service isEqualTo: newService])
        {
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: NSLocalizedString(@"The service is already in the list.", nil),
                                       NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"The service is already in the list.", nil),
                                       NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Check that you selected the correct service.", nil)
                                       };
            *error = [NSError errorWithDomain: [[NSBundle mainBundle] bundleIdentifier]
                                         code: -58
                                     userInfo: userInfo];
            return -1;
        }
    }
    [_services addObject: newService];
    /*[_libraries sortUsingComparator: ^NSComparisonResult(NSString *libPath1, NSString *libPath2)
     {
         NSString *name1 = [MMPhotoLibrary nameFromPath: libPath1];
         NSString *name2 = [MMPhotoLibrary nameFromPath: libPath2];
         return  [name1 localizedCompare: name2];
     }];*/
//    return [_libraries indexOfObject: newLibraryPath];
    return [self totalServices] - 1;
}

/**
 * Removes the service entry at a particular index
 */
- (void) removeServiceAtIndex: (NSUInteger) index
{
    [_services removeObjectAtIndex: index];
}

- (NSString *) serviceNameForIndex: (NSInteger) index
{
    MMSmugmug *service = [_services objectAtIndex: index];
    if (service)
    {
        return [service name];
    }
    else
    {
        return @"(none)";
    }
}

- (NSInteger) totalServices
{
    return [_services count];
}

@end
