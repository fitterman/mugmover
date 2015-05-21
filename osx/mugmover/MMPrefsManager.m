//
//  MMPrefsManager.m
//  mugmover
//
//  Created by Bob Fitterman on 5/21/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

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
    [defaults synchronize];
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
    [defaults synchronize];
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
    [defaults synchronize];
}

+ (void)   setBool: (BOOL) boolValue
            forKey: (NSString *) name
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject: [NSNumber numberWithBool: boolValue]
                 forKey: name];
    [defaults synchronize];
}

/**
 * Ensures each of the preference values has been set to something.
 */
+ (void) setDefaultPreferenceValues
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // FOR TESTING, WIPE THE DEFAULTS
    // [defaults removePersistentDomainForName:[[NSBundle mainBundle] bundleIdentifier]];
    
    if (![defaults objectForKey: @"retransmitFilesSentPreviously"])
    {
        [defaults setObject: [NSNumber numberWithBool: NO] forKey: @"retransmitFilesSentPreviously"];
    }
    
    // And save them away
    [defaults synchronize];
}

+ (void) setObject: (id) object
            forKey: (NSString *) name
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject: object forKey: name];
    [defaults synchronize];
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
    [defaults synchronize];
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
