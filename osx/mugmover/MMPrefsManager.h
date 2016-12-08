//
//  MMPrefsManager.h
//  mugmover
//
//  Created by Bob Fitterman on 5/21/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MMPrefsManager : NSObject

+ (BOOL) boolForKey: (NSString *) name;

+ (void) clearTokenAndSecretForDestination: (NSString *) destinationString
                                  uniqueId: (NSString *) uniqueId;

+ (void) deserializeLibrariesFromDefaultsMergingIntoMutableArray: (NSMutableArray *) mutableArray;

+ (void) deserializeDestinationsFromDefaultsMergingIntoMutableArray: (NSMutableArray *) mutableArray;

+ (id) objectForKey: (NSString *) name;

+ (void) serializeLibrariesToDefaults: (NSArray *) libraries;

+ (void) serializeDestinationsToDefaults: (NSArray *) destinations;

+ (void)   setBool: (BOOL) boolValue
            forKey: (NSString *) name;

+ (void) setDefaultPreferenceValues;

+ (void) setObject: (id) object
            forKey: (NSString *) name;

+ (void)  storeToken: (NSString *) accessToken
              secret: (NSString *) tokenSecret
      forDestination: (NSString *) destionationString
            uniqueId: (NSString *) uniqueId;

+ (void) syncIfNecessary: (NSUserDefaults *) defaults;

+ (NSArray *) tokenAndSecretForDestination: (NSString *) destinationString
                                  uniqueId: uniqueId;

@end
