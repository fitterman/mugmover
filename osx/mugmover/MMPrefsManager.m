//
//  MMPrefsManager.m
//  mugmover
//
//  Created by Bob Fitterman on 5/21/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMDataUtility.h"
#import "MMPrefsManager.h"
#import "MMDestinationFileSystem.h"
#import "MMDestinationSmugmug.h"

@implementation MMPrefsManager


+ (BOOL) boolForKey: (NSString *) name
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [[defaults objectForKey: name] boolValue];
}

+ (void) clearTokenAndSecretForDestination: (NSString *) destinationString
                                  uniqueId: (NSString *) uniqueId
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *atKey = [NSString stringWithFormat: @"%@.%@.accessToken", destinationString, uniqueId];
    NSString *tsKey = [NSString stringWithFormat: @"%@.%@.tokenSecret", destinationString, uniqueId];
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

+ (void) deserializeDestinationsFromDefaultsMergingIntoMutableArray: (NSMutableArray *) mutableArray
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *array = [defaults objectForKey: @"services"];
    if (array)
    {
        for (NSDictionary *dictionary in array)
        {
            NSString *destinationType = (NSString *)[dictionary objectForKey: @"type"];
            MMDestinationAbstract *destination = nil;
            if ([destinationType isEqualToString: @"smugmug"])
            {
                destination = [[MMDestinationSmugmug alloc] initFromDictionary: dictionary];
            }
            else if ([destinationType isEqualToString: @"filesystem"])
            {
                destination = [[MMDestinationFileSystem alloc] initFromDictionary: dictionary];
            }
            if (destination)
            {
                [mutableArray addObject: destination];
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
+ (void) serializeDestinationsToDefaults: (NSArray *) destinations
{
    NSMutableArray *serializedDestinations = [[NSMutableArray alloc] initWithCapacity: [destinations count]];
    for (MMDestinationSmugmug *destination in destinations)
    {
        [serializedDestinations addObject: [destination serialize]];
    }
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject: serializedDestinations forKey: @"services"];
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
      forDestination: (NSString *) destinationString
            uniqueId: (NSString *) uniqueId;
{
    NSString *atKey = [NSString stringWithFormat: @"%@.%@.accessToken", destinationString, uniqueId];
    NSString *tsKey = [NSString stringWithFormat: @"%@.%@.tokenSecret", destinationString, uniqueId];
    
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

+ (NSArray *) tokenAndSecretForDestination: (NSString *) destinationString
                                  uniqueId: uniqueId
{
    NSString *atKey = [NSString stringWithFormat: @"%@.%@.accessToken", destinationString, uniqueId];
    NSString *tsKey = [NSString stringWithFormat: @"%@.%@.tokenSecret", destinationString, uniqueId];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return @[[defaults objectForKey: atKey], [defaults objectForKey: tsKey]];
}

@end
