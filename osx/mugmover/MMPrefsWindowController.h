//
//  MMPrefsWindowController.h
//  mugmover
//
//  Created by Bob Fitterman on 5/19/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MMPrefsWindowController : NSWindowController
@property (weak)    IBOutlet    NSButton *          closeButton;
@property (strong)              NSUserDefaults *    defaults;
@property (weak)    IBOutlet    NSButton *          retransmitFiles;

+ (void) clearTokenAndSecretForService: (NSString *) serviceString
                              uniqueId: (NSString *) uniqueId;

+ (void) deserializeLibrariesFromDefaultsMergingIntoMutableArray: (NSMutableArray *) mutableArray;

+ (void) deserializeServicesFromDefaultsMergingIntoMutableArray: (NSMutableArray *) mutableArray;

+ (BOOL) getBoolForPreferenceNamed: (NSString *) name;

+ (NSArray *) getTokenAndSecretForService: (NSString *) serviceString
                                 uniqueId: uniqueId;

+ (void) serializeLibrariesToDefaults: (NSArray *) libraries;

+ (void) serializeServicesToDefaults: (NSArray *) services;

+ (void)   setBool: (BOOL) boolValue
forPreferenceNamed: (NSString *) name;

+ (void) setDefaultPreferenceValues;

+ (void)  storeToken: (NSString *) accessToken
              secret: (NSString *) tokenSecret
          forService: (NSString *) serviceString
            uniqueId: (NSString *) uniqueId;

@end
