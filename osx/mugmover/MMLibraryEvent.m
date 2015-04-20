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
    _eventThumbnail = [[NSImage alloc] initByReferencingFile: [self iconImagePath]];
    _currentThumbnail = _eventThumbnail;
    return self;
}

- (void) close
{
    _currentThumbnail = nil;
    _dictionary = nil;
    _eventThumbnail = nil;
}

- (NSString *) iconImagePath
{
    NSString *versionUuid = [_dictionary objectForKey: @"posterVersionUuid"];
    if (versionUuid)
    {
        MMPhoto *photo = [MMPhoto getPhotoByVersionUuid: versionUuid
                                            fromLibrary: _library];
        if (photo)
        {
            NSString *path = [photo originalImagePath];
            if (path)
            {
                return path;
            }
        }
    }
    return [[NSBundle mainBundle] pathForResource: @"Photograph-128" ofType: @"png"];
}

- (void) setActivePhotoThumbnail: (NSString *) photoThumbnailPath
                      withStatus: (MMEventStatus) status
{
    if (photoThumbnailPath)
    {
        _currentThumbnail = [[NSImage alloc] initByReferencingFile: photoThumbnailPath];
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
