//
//  MMLibraryEvent.h
//  mugmover
//
//  Created by Bob Fitterman on 4/4/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
@class MMPhotoLibrary;

@interface MMLibraryEvent : NSObject

@property (strong, readonly)    NSDictionary *      dictionary;
@property (weak)                MMPhotoLibrary *    library;

+ (NSArray *) getEventsFromLibrary: (MMPhotoLibrary *) library;

- (id) initFromDictionary: (NSDictionary *) inDictionary
                  library: (MMPhotoLibrary *) library;

- (NSString *) dateRange;

- (NSNumber *) filecount;

- (NSString *) iconImagePath;

- (NSString *) name;

- (NSString *) uuid;

@end
