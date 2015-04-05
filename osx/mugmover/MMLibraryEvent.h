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

+ (NSArray *) getEventsFromLibrary: (MMPhotoLibrary *) library;

- (id) initFromDictionary: (NSDictionary *) inDictionary;

- (NSString *) dateRange;

- (NSString *) name;

@end
