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

+ (void) clearTokenAndSecretForService: (NSString *) serviceString
                              uniqueId: (NSString *) uniqueId;

+ (void) deserializeLibrariesFromDefaultsMergingIntoMutableArray: (NSMutableArray *) mutableArray;

+ (void) deserializeServicesFromDefaultsMergingIntoMutableArray: (NSMutableArray *) mutableArray;

+ (id) objectForKey: (NSString *) name;

+ (void) serializeLibrariesToDefaults: (NSArray *) libraries;

+ (void) serializeServicesToDefaults: (NSArray *) services;

+ (void)   setBool: (BOOL) boolValue
            forKey: (NSString *) name;

+ (void) setDefaultPreferenceValues;

+ (void) setObject: (id) object
            forKey: (NSString *) name;

+ (void)  storeToken: (NSString *) accessToken
              secret: (NSString *) tokenSecret
          forService: (NSString *) serviceString
            uniqueId: (NSString *) uniqueId;

+ (void) syncIfNecessary: (NSUserDefaults *) defaults;

+ (NSArray *) tokenAndSecretForService: (NSString *) serviceString
                              uniqueId: uniqueId;

@end
