//
//  MMPrefsManager.m
//  mugmover
//
//  Created by Bob Fitterman on 5/21/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMDataUtility.h"
#import "MMPrefsManager.h"
#import "MMSMugmug.h"

@implementation MMPrefsManager


+ (BOOL) boolForKey: (NSString *) name
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [[defaults objectForKey: name] boolValue];
}

+ (void) clearTokenAndSecretForService: (NSString *) serviceString
                              uniqueId: (NSString *) uniqueId
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *atKey = [NSString stringWithFormat: @"%@.%@.accessToken", serviceString, uniqueId];
    NSString *tsKey = [NSString stringWithFormat: @"%@.%@.tokenSecret", serviceString, uniqueId];
    [defaults removeObjectForKey: atKey];
    [defaults removeObjectForKey: tsKey];
    [self syncIfNecessary: defaults];
}

+ (void) deserializeLibrariesFromDefaultsMergingIntoMutableArray: (NSMutableArray *) mutableArray
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *array = [defaults objectForKey: @"libraries"];
    if (array)
    {
        [mutableArray addObjectsFromArray: array];
    }
}

+ (void) deserializeServicesFromDefaultsMergingIntoMutableArray: (NSMutableArray *) mutableArray
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
                [mutableArray addObject: service];
            }
        }
    }
}

+ (id) objectForKey: (NSString *) name
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults objectForKey: name];
}

+ (void) serializeLibrariesToDefaults: (NSArray *) libraries
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject: libraries forKey: @"libraries"];
    [self syncIfNecessary: defaults];
}

/**
 * This expects to take in an array of SmugMug service objects. It will serialize them
 * and then store the array of serialized values
 */
+ (void) serializeServicesToDefaults: (NSArray *) services
{
    NSMutableArray *serializedServices = [[NSMutableArray alloc] initWithCapacity: [services count]];
    for (MMSmugmug *service in services)
    {
        [serializedServices addObject: [service serialize]];
    }
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject: serializedServices forKey: @"services"];
    [self syncIfNecessary: defaults];
}

+ (void)   setBool: (BOOL) boolValue
            forKey: (NSString *) name
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject: [NSNumber numberWithBool: boolValue]
                 forKey: name];
    [self syncIfNecessary: defaults];
}

/**
 * Ensures each of the preference values has been set to something.
 */
+ (void) setDefaultPreferenceValues
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // FOR TESTING, WIPE THE DEFAULTS
    // [defaults removePersistentDomainForName:[[NSBundle mainBundle] bundleIdentifier]];
    
    if (![defaults objectForKey: @"reprocessAllImagesPreviouslyTransmitted"])
    {
        [defaults setObject: [NSNumber numberWithBool: NO] forKey: @"reprocessAllImagesPreviouslyTransmitted"];
    }
    [self syncIfNecessary: defaults];
}

+ (void) setObject: (id) object
            forKey: (NSString *) name
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject: object forKey: name];
    [self syncIfNecessary: defaults];
}

+ (void)  storeToken: (NSString *) accessToken
              secret: (NSString *) tokenSecret
          forService: (NSString *) serviceString
            uniqueId: (NSString *) uniqueId;
{
    NSString *atKey = [NSString stringWithFormat: @"%@.%@.accessToken", serviceString, uniqueId];
    NSString *tsKey = [NSString stringWithFormat: @"%@.%@.tokenSecret", serviceString, uniqueId];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject: accessToken forKey: atKey];
    [defaults setObject: tokenSecret forKey: tsKey];
    [self syncIfNecessary: defaults];
}

+ (void) syncIfNecessary: (NSUserDefaults *) defaults
{
    static NSOperatingSystemVersion yosemite = {10, 10, 0};
    if (![[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion: yosemite])
    {
        [defaults synchronize];
    }
}

+ (NSArray *) tokenAndSecretForService: (NSString *) serviceString
                              uniqueId: uniqueId
{
    NSString *atKey = [NSString stringWithFormat: @"%@.%@.accessToken", serviceString, uniqueId];
    NSString *tsKey = [NSString stringWithFormat: @"%@.%@.tokenSecret", serviceString, uniqueId];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return @[[defaults objectForKey: atKey], [defaults objectForKey: tsKey]];
}

@end
