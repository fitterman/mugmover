//
//  MMLibraryEvent.m
//  mugmover
//
//  Created by Bob Fitterman on 4/4/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMLibraryEvent.h"
#import "MMPhotoLibrary.h"
#import <FMDatabase.h>
#import <FMDB/FMDatabaseAdditions.h>

@implementation MMLibraryEvent

/**
 Returns an array of dictionaries, each containing the keys "uuid", "name", "dateRange"
 for an event. Note that name may be a nil value, indicating that the event has not
 been named, in which case...
 */
+ (NSArray *) getEventsFromLibrary: (MMPhotoLibrary *) library
{
    NSInteger upperRecordCount  = [library.photosDatabase
                                   intForQuery: @"SELECT count(*) FROM RKFolder "
                                   "WHERE isMagic != 1 AND isHidden != 1 AND isInTrash != 1 "];
    
    NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity: upperRecordCount];
    
    NSString *query =  @"SELECT minImageDate, minImageTimeZoneName, "
    "maxImageDate, maxImageTimeZoneName, name, versionCount "
    "FROM RKFolder "
    "WHERE isMagic != 1 AND isHidden != 1 AND isInTrash != 1 "
    "ORDER BY minImageDate, maxImageDate, uuid;";
    
    
    // NOTE: It has been observed that in some cases, the minImageDate or maxImageDate
    //       might be a NULL value if the database didn't update that yet.
    
    FMResultSet *resultSet = [library.photosDatabase executeQuery: query withArgumentsInArray: @[]];
    while (resultSet && [resultSet next])
    {
        [result addObject: [[MMLibraryEvent alloc] initFromDictionary: [resultSet resultDictionary]]];
    }
    [resultSet close];
    return (NSArray *)result;
}

- (id) initFromDictionary: (NSDictionary *) inDictionary
{
    _dictionary = inDictionary;
    return self;
}

- (void) close
{
    _dictionary = nil;
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
    return [results componentsJoinedByString: @" to "];
}
- (NSString *) name
{
    return [_dictionary objectForKey: @"name"];
}
@end
