//
//  MMPrefsWindowController.m
//  mugmover
//
//  Created by Bob Fitterman on 5/19/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMPrefsWindowController.h"
#import "MMSMugmug.h"

@interface MMPrefsWindowController ()

@end

@implementation MMPrefsWindowController


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

+ (BOOL) getBoolForPreferenceNamed: (NSString *) name
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [[defaults objectForKey: name] boolValue];
}

+ (NSArray *) getTokenAndSecretForService: (NSString *) serviceString
                                 uniqueId: uniqueId
{
    NSString *atKey = [NSString stringWithFormat: @"%@.%@.accessToken", serviceString, uniqueId];
    NSString *tsKey = [NSString stringWithFormat: @"%@.%@.tokenSecret", serviceString, uniqueId];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return @[[defaults objectForKey: atKey], [defaults objectForKey: tsKey]];
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
forPreferenceNamed: (NSString *) name
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

- (id) init
{
    self = [super initWithWindowNibName:@"MMPrefsWindowController"];
    _defaults = [NSUserDefaults standardUserDefaults];
    return self;
}

- (IBAction)closeButtonWasPressed:(id)sender
{
    [MMPrefsWindowController setBool: [_retransmitFiles state]
                  forPreferenceNamed: @"retransmitFilesSentPreviously"];
    _defaults = nil; // releases the object

    [self.window.sheetParent endSheet: self.window
                           returnCode: NSModalResponseCancel];
}

- (void) windowDidLoad
{
    [super windowDidLoad];
    [_retransmitFiles setState: [MMPrefsWindowController
                                 getBoolForPreferenceNamed: @"retransmitFilesSentPreviously"]];
}

@end
