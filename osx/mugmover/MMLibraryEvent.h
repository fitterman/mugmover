//
//  MMLibraryEvent.h
//  mugmover
//
//  Created by Bob Fitterman on 4/4/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
@class MMPhoto;
@class MMPhotoLibrary;

typedef NS_ENUM(NSInteger, MMEventStatus) {
    MMEventStatusNone,
    MMEventStatusActive,
    MMEventStatusCompleted,
};

@interface MMLibraryEvent : NSObject

@property (weak, nonatomic)     MMPhoto *           activePhoto;
@property (strong, readonly)    NSDictionary *      dictionary;
@property (weak)                MMPhotoLibrary *    library;
@property (assign)              NSInteger           row; // An index into the array of events
@property (assign)              MMEventStatus       status;
@property (assign)              BOOL                toBeProcessed;

+ (NSArray *) getEventsFromLibrary: (MMPhotoLibrary *) library;

- (id) initFromDictionary: (NSDictionary *) inDictionary
                      row: (NSInteger) row
                  library: (MMPhotoLibrary *) library;

- (NSString *) dateRange;

- (NSNumber *) filecount;

- (NSString *) iconImagePath;

- (NSString *) name;

- (void) setActivePhoto: (MMPhoto *) photo;

- (NSString *) uuid;


@end
