//
//  MMServiceManager.m
//  mugmover
//
//  Created by Bob Fitterman on 4/28/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMPhotoLibrary.h"
#import "MMPrefsManager.h"
#import "MMServiceManager.h"
#import "MMServiceSmugmug.h"
#import "MMWindowController.h"

NSInteger const maxSupportedServices = 50;

@implementation MMServiceManager

- (id) initForWindowController: (id) windowController
{
    self = [super init];
    if (self)
    {
        _windowController = windowController;
        _services = [[NSMutableArray alloc] initWithCapacity: maxSupportedServices];
        [MMPrefsManager deserializeServicesFromDefaultsMergingIntoMutableArray: _services];
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
- (NSInteger) insertService: (MMServiceAbstract *) newService
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
    for (MMServiceAbstract *service in _services)
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

    [MMPrefsManager storeToken: [newService oauthAccessToken]
                        secret: [newService oauthTokenSecret]
                    forService: [newService identifier]
                      uniqueId: newService.uniqueId];
    [MMPrefsManager serializeServicesToDefaults: _services];
    return [self totalServices] - 1;
}

/**
 * Removes the service entry at a particular index
 */
- (void) removeServiceAtIndex: (NSUInteger) index
{
    [_services removeObjectAtIndex: index];
    [MMPrefsManager serializeServicesToDefaults: _services];
}

- (MMServiceSmugmug *) serviceForIndex: (NSInteger) index
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
    MMServiceSmugmug *service = [self serviceForIndex: index];
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
