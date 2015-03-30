//
//  MMFlickrPhotostream.m
//  Everything to do with a Flickr Photostream (that is the stream itself, not the
//  access to data from individual images contained in the stream). Once the
//  initialization has completed, the bulk of this class is used to queue
//  requests to process each individual photo. See the MMPhoto class for further details.
//
//  Created by Bob Fitterman on 11/13/14.
//  Copyright (c) 2014 Dicentra LLC. All rights reserved.
//

#import "MMFlickrPhotostream.h"
#import "MMOauthFlickr.h"
#import "MMPhoto.h"
#import "MMPhotoLibrary.h"

@implementation MMFlickrPhotostream

#define PHOTOS_PER_REQUEST (10)
const NSInteger MMDefaultRetries = 3;

NSDictionary       *photoResponseDictionary;
long                retryCount;

- (id) initWithHandle: (NSString *) flickrHandle
          libraryPath: (NSString *) libraryPath
{
    self = [self init];
    if (self)
    {

        if (!flickrHandle || !libraryPath)
        {
            return nil;
        }
        _library = [[MMPhotoLibrary alloc] initWithPath: (NSString *) libraryPath];
        if (!_library)
        {
            [self close];
            return nil;
        }

        _photoDictionary = [[NSMutableDictionary alloc] init];
        if (!_photoDictionary)
        {
            [self close];
            return nil;
        }
        self.handle = flickrHandle;
        _page = 1; // Flickr counts from 1
        _currentPhotoIndex = (_page - 1) * PHOTOS_PER_REQUEST;

        _flickrOauth = [[MMOauthFlickr alloc] initAndStartAuthorization: ^(Float32 progress, NSString *text)
                        {
                            self.initializationProgress = progress;
                        }];
        _streamQueue = [NSOperationQueue mainQueue];

        // TODO Get this running in another thread
        //_streamQueue = [[NSOperationQueue alloc] init];
        //[_streamQueue setMaxConcurrentOperationCount:  NSOperationQueueDefaultMaxConcurrentOperationCount];
    }
    return self;
}

- (void) close
{
    _accessSecret = nil;
    _accessToken = nil;
    _currentPhoto = nil;
    if (_flickrOauth)
    {
        [_flickrOauth close];
        _flickrOauth = nil;
    }
    _handle = nil;
    if (_library)
    {
        [_library close];
        _library = nil;
    }
    _photoDictionary = nil;
    _streamQueue = nil;
}

-(NSInteger)inQueue
{
    return [_photoDictionary count];
}


- (void) getPhotos
{
    NSString *userId = @"127850168@N06"; // TODO Don't hardcode this

    NSURLRequest *request = [_flickrOauth apiRequest: @"flickr.people.getPhotos"
                                          parameters: @{@"per_page": [NSString stringWithFormat: @"%d", PHOTOS_PER_REQUEST],
                                                        @"page":     [NSString stringWithFormat: @"%ld", _page],
                                                        @"user_id":  userId,
                                                       }
                                                verb: @"GET"];
    ServiceResponseHandler processGetPhotosResponse = ^(NSDictionary *responseDictionary)
    {
        photoResponseDictionary = responseDictionary;
        if (!self.photosInStream)
        {
            _photosInStream = [[photoResponseDictionary valueForKeyPath: @"photos.total"] integerValue];
        }
        NSArray *photos =[photoResponseDictionary valueForKeyPath: @"photos.photo"];
        // If you get an empty buffer back, that means there are no more photos to be had: quit trying
        if ((!photos) || ([photos count] == 0))
        {
            DDLogInfo(@"END OF STREAM");
            [self close];
            return;
        }
        for (NSDictionary *photoToBeReturned in photos)
        {
            MMPhoto *photo = [[MMPhoto alloc] initWithFlickrDictionary: photoToBeReturned
                                                                stream: self
                                                                 index: ++_currentPhotoIndex];
            NSString *photoKey = [NSString stringWithFormat: @"%lx", (NSInteger)(photo)];
            [_photoDictionary setObject: photo forKey: photoKey];
            
            NSBlockOperation *returnPhoto = [NSBlockOperation blockOperationWithBlock:^
                                             {
                                                 DDLogInfo(@"QUEUEING      %lu/%lu",
                                                           photo.index,
                                                           (long)_photosInStream);
                                                 [photo performNextStep];
                                             }
                                             ];
            [self.streamQueue addOperation: returnPhoto];
        }
        return;
    };
    [_flickrOauth processUrlRequest: request
                              queue: _streamQueue
                  remainingAttempts: MMDefaultRetries
                  completionHandler: processGetPhotosResponse];
}
- (void) removeFromPhotoDictionary: (MMPhoto *) photo
{
    NSString *photoKey = [NSString stringWithFormat: @"%lx", (NSInteger)(photo)];
    [_photoDictionary removeObjectForKey: photoKey];
    if ([_photoDictionary count] == 0)
    {
        _page++;
        [self getPhotos];
    }
}

@end
