//
//  MMLibraryEvent.m
//  mugmover
//
//  Created by Bob Fitterman on 4/4/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMLibraryEvent.h"
#import "MMPhoto.h"
#import "MMPhotoLibrary.h"
#import "MMMasterViewController.h"
#import <FMDatabase.h>
#import <FMDB/FMDatabaseAdditions.h>

@implementation MMLibraryEvent

- (id) initFromDictionary: (NSDictionary *) inDictionary
                      row: (NSInteger) row
                  library: (MMPhotoLibrary *) library
{
    _dictionary = inDictionary;
    _library = library;
    _row = row;
    _status = MMEventStatusNone;
    _eventThumbnail = [self iconImage];
    _currentThumbnail = _eventThumbnail;
    return self;
}

- (void) close
{
    _currentThumbnail = nil;
    _dictionary = nil;
    _eventThumbnail = nil;
}

- (NSImage *) iconImage
{
    NSString *versionUuid = [self featuredImageUuid];
    if (versionUuid)
    {
        MMPhoto *photo = [MMPhoto getPhotoByVersionUuid: versionUuid
                                            fromLibrary: _library];
        if (photo)
        {
            return [photo getThumbnailImage];
        }
    }
    NSString *pathToIcon = [[NSBundle mainBundle] pathForResource: @"Photograph-128" ofType: @"png"];
    return [[NSImage alloc] initByReferencingFile: pathToIcon];
}

- (void) setActivePhotoThumbnail: (NSImage *) photoThumbnailImage
                      withStatus: (MMEventStatus) status
{
    if (photoThumbnailImage)
    {
        _currentThumbnail = photoThumbnailImage;
    }
    else
    {
        _currentThumbnail = _eventThumbnail;
    }
    _status = status;
}

- (NSString *) dateRange
{
    NSArray *dates = @[[_dictionary objectForKey: @"minImageDate"],
                       [_dictionary objectForKey: @"maxImageDate"]];

    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    dateFormat.timeStyle = NSDateFormatterNoStyle;
    dateFormat.dateStyle = NSDateFormatterMediumStyle;
    
    NSMutableArray *results = [[NSMutableArray alloc] initWithCapacity: 2];
    for (NSNumber *date in dates)
    {
        if (!date)
        {
            return @"(unknown dates)";
        }

        NSDate *dateTimestamp = [[NSDate alloc] initWithTimeIntervalSinceReferenceDate: (NSTimeInterval) [date doubleValue]];
        
        NSString *zone = [_dictionary objectForKey: @"minImageTimeZoneName"];

        if ((!zone) || ((NSNull *)zone == [NSNull null]) || ([zone length] == 0))
        {
            dateFormat.timeZone = [NSTimeZone timeZoneWithName: @"UTC"];
        }
        else
        {
            dateFormat.timeZone = [NSTimeZone timeZoneWithName: zone];
        }

        zone = [_dictionary objectForKey: @"maxImageTimeZoneName"];
        
        [results addObject: [dateFormat stringFromDate: dateTimestamp]];
    }
    if ([[results objectAtIndex: 0] isEqualToString: [results objectAtIndex: 1]])
    {
        [results removeLastObject];
    }
    return [results componentsJoinedByString: @" – "];
}

#pragma mark Attribute Accessors
- (NSString *) featuredImageUuid
{
    return [_dictionary objectForKey: @"posterVersionUuid"];
}
- (NSNumber *) filecount
{
    return [_dictionary objectForKey: @"filecount"];
}

- (NSString *) name
{
    return [_dictionary objectForKey: @"name"];
}

- (NSString *) uuid
{
    return [_dictionary objectForKey: @"uuid"];
}
@end
