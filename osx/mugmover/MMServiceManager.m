//
//  MMServiceManager.m
//  mugmover
//
//  Created by Bob Fitterman on 4/28/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMPhotoLibrary.h"
#import "MMServiceManager.h"
#import "MMMasterViewController.h"
#import "MMSmugmug.h"
#import "MMOauthAbstract.h"

NSInteger const maxSupportedServices = 50;

@implementation MMServiceManager

- (id) initForViewController: (id) viewController
{
    self = [super init];
    if (self)
    {
        _viewController = viewController;
        _services = [[NSMutableArray alloc] initWithCapacity: maxSupportedServices];
        [self deserializeFromDefaults];
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

    NSString *atKey = [NSString stringWithFormat: @"smugmug.%@.accessToken", newService.uniqueId];
    NSString *tsKey = [NSString stringWithFormat: @"smugmug.%@.tokenSecret", newService.uniqueId];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    MMOauthAbstract *oa = (MMOauthAbstract *)newService.smugmugOauth;
    [defaults setObject: oa.accessToken forKey: atKey];
    [defaults setObject: oa.tokenSecret forKey: tsKey];
    [defaults synchronize];

    [self serializeToDefaults];
    return [self totalServices] - 1;
}

/**
 * Removes the service entry at a particular index
 */
- (void) removeServiceAtIndex: (NSUInteger) index
{
    [_services removeObjectAtIndex: index];
    [self serializeToDefaults];
}

- (void) deserializeFromDefaults
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *array = [defaults objectForKey: @"services"];
    if (array)
    {
        for (NSDictionary *dictionary in array)
        {
            MMSmugmug *service = [[MMSmugmug alloc] initFromDictionary: dictionary];
            if (service)
            {
                [_services addObject: service];
            }
        }
    }
}

- (void) serializeToDefaults
{
    NSMutableArray *serializedServices = [[NSMutableArray alloc] initWithCapacity: [self totalServices]];
    for (MMSmugmug *service in _services)
    {
        [serializedServices addObject: [service serialize]];
    }
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject: serializedServices forKey: @"services"];
    [defaults synchronize];
}

- (MMSmugmug *) serviceForIndex: (NSInteger) index
{
    if ((0 <= index) && (index < _services.count))
    {
        return [_services objectAtIndex: index];
    }
    else
    {
        return nil;
    }
}

- (NSString *) serviceNameForIndex: (NSInteger) index
{
    MMSmugmug *service = [self serviceForIndex: index];
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
