//
//  MMDestinationAbstract.m
//  mugmover
//
//  Created by Bob Fitterman on 12/7/16.
//  Copyright © 2016 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MMDestinationAbstract.h"

@implementation MMDestinationAbstract : NSObject ;

- (id) init
{
    self = [super init];
    if (self)
    {
        _uniqueId = nil;
        _errorLog = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void) close
{
    _accessSecret = nil;
    _accessToken = nil;
    _currentPhoto = nil;
    _errorLog = nil;
    _uniqueId = nil;
}

- (NSString *) findOrCreateFolderForLibrary: library
{
    [NSException raise:NSInternalInconsistencyException
                format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
    return nil;
}

- (NSString *) identifier
{
    [NSException raise:NSInternalInconsistencyException
                format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
    return nil;
}

/**
 * Adds an error to a sequential log of errors
 */
- (void) logError: (NSError *) error
{
    NSDictionary *logRecord =@{@"time": [NSDate date], @"error": error};
    [self.errorLog addObject: logRecord];
}

- (NSString *) name
{
    [NSException raise:NSInternalInconsistencyException
                format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
    return nil;
}

- (NSString *) oauthAccessToken
{
    [NSException raise:NSInternalInconsistencyException
                format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
    return nil;
}

- (NSString *) oauthTokenSecret
{
    [NSException raise:NSInternalInconsistencyException
                format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
    return nil;
}

- (NSDictionary *) serialize
{
    return @{@"type":   [self identifier],
             @"id":     self.uniqueId};
}

- (void) transferPhotosForEvent: (MMLibraryEvent *) event
                uploadOperation: (MMUploadOperation *) uploadOperation
               windowController: (MMWindowController *) windowController
                       folderId: (NSString *) folderId
{
    [NSException raise:NSInternalInconsistencyException
                format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];    
}

@end
