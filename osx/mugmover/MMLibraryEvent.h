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
    MMEventStatusIncomplete,
    MMEventStatusCompleted,
};

@interface MMLibraryEvent : NSObject

@property (strong, readonly)    NSImage *           currentThumbnail;
@property (strong, readonly)    NSDictionary *      dictionary;
@property (strong, readonly)    NSImage *           eventThumbnail;
@property (weak)                MMPhotoLibrary *    library;
@property (assign)              NSInteger           row; // An index into the array of events
@property (assign)              MMEventStatus       status;
@property (assign)              BOOL                toBeProcessed;

- (id) initFromDictionary: (NSDictionary *) inDictionary
                      row: (NSInteger) row
                  library: (MMPhotoLibrary *) library;

- (NSString *) dateRange;

- (NSString *) featuredImageUuid;

- (NSNumber *) filecount;

- (NSImage *) iconImage;

- (NSString *) name;

- (void) setActivePhotoThumbnail: (NSImage *) photoThumbnailImage
                      withStatus: (MMEventStatus) status;

- (NSString *) uuid;


@end
