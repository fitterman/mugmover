//
//  MMFlickrPhotostream.m
//  mugmover
//
//  Created by Bob Fitterman on 11/13/14.
//  Copyright (c) 2014 Dicentra LLC. All rights reserved.
//

#import "MMFlickrPhotostream.h"
#import "MMFlickrRequest.h"
#import "MMFlickrRequestPool.h"
#import "MMPhoto.h"
#import "MMPhotoLibrary.h"

@implementation MMFlickrPhotostream

NSInteger           nextPhotoToDeliver;
NSInteger           page;
NSInteger           photosInBuffer;
NSInteger           photosPerPage;
NSDictionary       *photoResponseDictionary;
long                retryCount;

- (id)initWithHandle: (NSString *)flickrHandle
         libraryPath: (NSString *)libraryPath
{
    self = [self init];
    if (self)
    {
        
        if (!flickrHandle || !libraryPath)
        {
            return nil;
        }
        _library = [[MMPhotoLibrary alloc] initWithPath: (NSString *)libraryPath];
        if (!_library)
        {
            return nil;
        }
        
        _photoDictionary = [[NSMutableDictionary alloc] init];
        if (!_photoDictionary)
        {
            _library = nil;
            return nil;
        }
        self.handle = flickrHandle;
        photosInBuffer = 0;
        nextPhotoToDeliver = 0;
        page = 1;
        self.initializationProgress = 0.0;
     
        [[NSAppleEventManager sharedAppleEventManager] setEventHandler: self
                                                           andSelector: @selector(handleIncomingURL:withReplyEvent:)
                                                         forEventClass: kInternetEventClass
                                                            andEventID: kAEGetURL];

        // NSLog(@"STEP 1 Create the OFFlickr request object");
        self.initializationProgress = 0.2; // That's 1 out of 5 steps
        _flickrContext = [[OFFlickrAPIContext alloc] initWithAPIKey: MUGMOVER_API_KEY_MACRO
                                                       sharedSecret: MUGMOVER_SHARED_SECRET_MACRO];
        _requestPool = [[MMFlickrRequestPool alloc] initWithContext: _flickrContext];
        if (!_requestPool)
        {
            NSLog(@"ERROR    Unable to initialize pool!");
        }
        OFFlickrAPIRequest *flickrRequest = [_requestPool getRequestFromPoolSettingDelegate: self];
        
        // NSLog(@"STEP 2 Initiate the OAuth the request");
        self.initializationProgress = 0.4; // That's 2 out of 5 steps
        // Initiate the request, giving Flickr the mugmover callback to hit
        [flickrRequest fetchOAuthRequestTokenWithCallbackURL: [NSURL URLWithString: @"mugmover:callback"]];
        
        _streamQueue = [NSOperationQueue mainQueue] ;
        //[NSOperationQueue new];
        //[_streamQueue setMaxConcurrentOperationCount: 12];
    }
    return self;
}

- (void) close
{
    _accessSecret = nil;
    _accessToken = nil;
    _currentPhoto = nil;
    _flickrContext = nil;
    _handle = nil;
    _library = nil;
    _photoDictionary = nil;
    _streamQueue = nil;
}

-   (void)flickrAPIRequest: (OFFlickrAPIRequest *)inRequest
didObtainOAuthRequestToken: (NSString *)inRequestToken
                    secret: (NSString *)inSecret
{
    
    // NSLog(@"STEP 3 Use the request token");
    // NSLog(@"       request=%@", inRequest);
    // NSLog(@"       requestToken=%@", inRequestToken);
    // NSLog(@"       secret=%@", inSecret);
    self.initializationProgress = 0.6; /* That's 3 out of 5 steps */

    _flickrContext.OAuthToken = inRequestToken;
    _flickrContext.OAuthTokenSecret = inSecret;
    
    [_requestPool returnRequestToPool: inRequest];
    //    [progressLabel setStringValue: @"Pending your approval..."];
    
    NSURL *authURL = [_flickrContext userAuthorizationURLWithRequestToken: inRequestToken
                                                      requestedPermission: OFFlickrWritePermission];
    // NSLog(@"       authUrl=%@", [authURL absoluteString]);
    [[NSWorkspace sharedWorkspace] openURL: authURL];
    
}

- (void)handleIncomingURL: (NSAppleEventDescriptor *)event
           withReplyEvent: (NSAppleEventDescriptor *)replyEvent
{
    // NSLog(@"STEP 4 Handle incoming (mugmover) URL");
    self.initializationProgress = 0.8; /* That's 4 out of 5 steps */
    
    NSURL *callbackURL = [NSURL URLWithString: [[event paramDescriptorForKeyword: keyDirectObject] stringValue]];
    // NSLog(@"       callbackURL=%@", [callbackURL absoluteString]);
    
    NSString *requestToken= nil;
    NSString *verifier = nil;
    
    BOOL result = OFExtractOAuthCallback(callbackURL, [NSURL URLWithString: @"mugmover:callback"], &requestToken, &verifier);
    if (!result)
    {
        // NSLog(@"ERROR Invalid callback URL");
        self.initializationProgress = -1.0;
    }
    OFFlickrAPIRequest *flickrRequest = [_requestPool getRequestFromPoolSettingDelegate: self];
    [flickrRequest fetchOAuthAccessTokenWithRequestToken: requestToken verifier: verifier];
}

-      (void)flickrAPIRequest: (OFFlickrAPIRequest *)inRequest
    didObtainOAuthAccessToken: (NSString *)inAccessToken
                       secret: (NSString *)inSecret
                 userFullName: (NSString *)inFullName
                     userName: (NSString *)inUserName
                     userNSID: (NSString *)inNSID
{
    // NSLog(@"STEP 5 You're in. Save the access token");
    // NSLog(@"       request=%@", inRequest);
    // NSLog(@"       accessToken=%@", inAccessToken);
    // NSLog(@"       accessToken=%@", inSecret);
    // NSLog(@"       userFullName=%@", inFullName);
    // NSLog(@"       username=%@", inUserName);
    // NSLog(@"       nsid=%@", inNSID);
    _accessToken = inAccessToken;
    _accessSecret = inSecret;
    _flickrContext.OAuthToken = inAccessToken;
    _flickrContext.OAuthTokenSecret = inSecret;
    
    [_requestPool returnRequestToPool: inRequest];
    self.initializationProgress = 1.0; /* That's 5 out of 5 steps */

}

- (void)nextPhoto
{
    if ((photosInBuffer == 0) || (nextPhotoToDeliver >= photosInBuffer))
    {
        OFFlickrAPIRequest *flickrRequest = [_requestPool getRequestFromPoolSettingDelegate: self];
        if ([flickrRequest isRunning])
        {
            @throw [NSException exceptionWithName: @"PoolManagement"
                                           reason: @"Pool request is still running"
                                         userInfo: nil];

        }
        NSBlockOperation *getPhotosOperation = [NSBlockOperation blockOperationWithBlock:^
                                                {
                                                    flickrRequest.sessionInfo = @"nextPhoto";
                                                    [flickrRequest callAPIMethodWithGET: @"flickr.people.getPhotos"
                                                                              arguments: [NSDictionary dictionaryWithObjectsAndKeys: @"400", @"per_page",
                                                                                          [NSString stringWithFormat: @"%ld", page], @"page",
                                                                                          /* TODO */ @"127850168@N06", @"user_id",
                                                                                          nil]];
                                                }];
        [self.streamQueue addOperation: getPhotosOperation];
    }
    else
    {
        // We are ready to return the photo, but first we have to get the exif data,
        // because it comes back looking like it's all done in a single request.

        NSDictionary *photoToBeReturned = [[photoResponseDictionary valueForKeyPath: @"photos.photo"] objectAtIndex: nextPhotoToDeliver];
        NSString *photo_id = [photoToBeReturned objectForKey: @"id"];
        NSString *secret = [photoToBeReturned objectForKey: @"secret"];
        NSBlockOperation *fetchExtraOperation = [NSBlockOperation blockOperationWithBlock:^
                                                {
                                                    [self fetchExifUsingPhotoId: photo_id secret: secret];
                                                    [self fetchInfoUsingPhotoId: photo_id secret: secret];
                                                }];
        [self.streamQueue addOperation: fetchExtraOperation];
    }
}

- (void)addFaceNoteTo: (NSString *)flickrPhotoid
                 face: (MMFace *)face
{
    OFFlickrAPIRequest *flickrRequest = [_requestPool getRequestFromPoolSettingDelegate: self];
    if ([flickrRequest isRunning])
    {
        @throw [NSException exceptionWithName: @"PoolManagement"
                                       reason: @"Pool request is still running (in addFaceNoteTo)"
                                     userInfo: nil];
        
    }
    flickrRequest.sessionInfo = @"addNote";
    // add a note for this face
    NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys: flickrPhotoid, @"photo_id",
                          face.flickrNoteX, @"note_x",
                          face.flickrNoteY, @"note_y",
                          face.flickrNoteWidth, @"note_w",
                          face.flickrNoteHeight, @"note_h",
                          face.flickrNoteText, @"note_text",
                          MUGMOVER_API_KEY_MACRO, @"api_key",
                          nil];
    [flickrRequest callAPIMethodWithPOST: @"flickr.photos.notes.add"
                                    arguments: args];
}

- (void)deleteNote: (NSString *)noteId
{
    OFFlickrAPIRequest *flickrRequest = [_requestPool getRequestFromPoolSettingDelegate: self];
    if ([flickrRequest isRunning])
    {
        @throw [NSException exceptionWithName: @"PoolManagement"
                                       reason: @"Pool request is still running (in deleteNoteFrom)"
                                     userInfo: nil];
        
    }
    NSArray  *pieces = [NSArray arrayWithObjects: @"deleteNote", noteId, nil];
    flickrRequest.sessionInfo = [pieces componentsJoinedByString: @";"];

    NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys: noteId, @"note_id",
                          MUGMOVER_API_KEY_MACRO, @"api_key",
                          nil];
    [flickrRequest callAPIMethodWithPOST: @"flickr.photos.notes.delete"
                               arguments: args];
}

- (void)fetchExifUsingPhotoId: (NSString *)photoId
                       secret: (NSString *)secret
{
    OFFlickrAPIRequest *flickrRequest = [_requestPool getRequestFromPoolSettingDelegate: self];
    if ([flickrRequest isRunning])
    {
        @throw [NSException exceptionWithName: @"PoolManagement"
                                       reason: @"Pool request is still running"
                                     userInfo: nil];
        
    }

    NSArray  *pieces = [NSArray arrayWithObjects: @"fetchExif", photoId, secret, nil];
    flickrRequest.sessionInfo = [pieces componentsJoinedByString: @";"];
    [flickrRequest callAPIMethodWithGET: @"flickr.photos.getExif"
                              arguments: [NSDictionary dictionaryWithObjectsAndKeys: photoId, @"photo_id",
                                          secret, @"secret",
                                          nil]];

}

- (void)fetchInfoUsingPhotoId: (NSString *)photoId
                       secret: (NSString *)secret
{
    OFFlickrAPIRequest *flickrRequest = [_requestPool getRequestFromPoolSettingDelegate: self];
    if ([flickrRequest isRunning])
    {
        @throw [NSException exceptionWithName: @"PoolManagement"
                                       reason: @"Pool request is still running"
                                     userInfo: nil];
        
    }

    NSArray  *pieces = [NSArray arrayWithObjects: @"fetchInfo", photoId, secret, nil];
    flickrRequest.sessionInfo = [pieces componentsJoinedByString: @";"];
    [flickrRequest callAPIMethodWithGET: @"flickr.photos.getInfo"
                              arguments: [NSDictionary dictionaryWithObjectsAndKeys: photoId, @"photo_id",
                                          secret, @"secret",
                                          nil]];
    
}

- (void)removeFromPhotoDictionary: (MMPhoto *)photo
{
    NSString *photoKey = [NSString stringWithFormat:@"%lx", (NSInteger)(photo)];
    [_photoDictionary removeObjectForKey: photoKey];
}

#pragma mark ObjectiveFlickr delegate methods

- (void)flickrAPIRequest: (OFFlickrAPIRequest *)inRequest
 didCompleteWithResponse: (NSDictionary *)inResponseDictionary
{
//    // NSLog(@"  COMPLETION: request=%@", inRequest.sessionInfo);
    if ([inRequest.sessionInfo hasPrefix: @"fetchExif;"])
    {
        retryCount = 0;
        NSArray *exifArray = [inResponseDictionary valueForKeyPath: @"photo.exif"];
        NSMutableDictionary  *exifData = [NSMutableDictionary new];
        for (id dict in exifArray)
        {
            NSString *tag = [(NSDictionary *)dict objectForKey: @"tag"];
            NSString *tagspace = [(NSDictionary *)dict objectForKey: @"tagspace"];
            NSDictionary *raw = [(NSDictionary *)dict objectForKey: @"raw"];

            NSArray *pieces = [NSArray arrayWithObjects: tagspace, tag, nil];
            [exifData setObject: [raw valueForKey: @"_text"] forKey: [pieces componentsJoinedByString: @":"]];
        }
        
        NSDictionary *photoToBeReturned = [[photoResponseDictionary valueForKeyPath: @"photos.photo"] objectAtIndex: nextPhotoToDeliver];
        /* Here we subtract 2 because (a) Flickr counts page from 1 not zero and (b) "page" always points to the NEXT page */
        self.currentPhotoIndex = ((page - 2) * photosPerPage) + nextPhotoToDeliver;
        nextPhotoToDeliver++; /* Point to the next NOW so if you are re-entered, you are already on the next */
        NSBlockOperation *returnPhoto = [NSBlockOperation blockOperationWithBlock:^
                                            {
                                                // // NSLog (@"  BLOCK returning photo with exif");
                                                MMPhoto *photo = [[MMPhoto alloc] initWithFlickrDictionary: photoToBeReturned
                                                                                            exifDictionary: exifData
                                                                                                    stream: self];
                                                
                                                NSString *photoKey = [NSString stringWithFormat:@"%lx", (NSInteger)(photo)];
                                                [_photoDictionary setObject: photo forKey: photoKey];
                                                self.currentPhoto = photo;
                                            }];
        [self.streamQueue addOperation: returnPhoto];
    }
    else if ([inRequest.sessionInfo hasPrefix: @"fetchInfo;"])
    {
        retryCount = 0;
        /* CAUTION: FetchInfo operation implies all the mugmover notes will be deleted. */
        NSArray *noteArray = [inResponseDictionary valueForKeyPath: @"photo.notes.note"];
        if (noteArray)
        {
            for (id dict in noteArray)
            {
                NSString *noteId = [(NSDictionary *)dict objectForKey: @"id"];
                NSString *noteText = [dict valueForKey: @"_text"];
                if (noteText)
                {
                    NSRange result = [noteText rangeOfString: @"mugmover" options: NSCaseInsensitiveSearch];
                    if (result.location != NSNotFound)
                    {
                        NSBlockOperation *deleteNote = [NSBlockOperation blockOperationWithBlock:^
                                                        {
                                                            [self deleteNote: noteId];
                                                        }];
                        [self.streamQueue addOperation: deleteNote];
                    }
                }
            }
        }
    }
    else if ([inRequest.sessionInfo hasPrefix: @"addNote"])
    {
        retryCount = 0;
        /* If it worked, there's nothing to do. */
    }
    else if ([inRequest.sessionInfo isEqualToString: @"nextPhoto"])
    {
        photoResponseDictionary = inResponseDictionary;
        photosInBuffer = [[photoResponseDictionary valueForKeyPath: @"photos.photo"] count];
        if (!self.photosInStream)
        {
            self.photosInStream = [[photoResponseDictionary valueForKeyPath: @"photos.total"] integerValue];
            photosPerPage = [[photoResponseDictionary valueForKeyPath: @"photos.perpage"] integerValue];
        }
        /* If you get an empty buffer back, that means there are no more photos to be had: quit trying */
        if (photosInBuffer != 0)
        {
            nextPhotoToDeliver = 0;
            page++;
            retryCount = 0;
            [self nextPhoto];
        }
    }
}

- (BOOL) trackFailedAPIRequest: (OFFlickrAPIRequest *)inRequest
                         error: (NSError *)inError
{
    NSLog(@"ERROR flickrAPIRequest failed %@ (code=%lx), sessionInfo=\"%@\" retryCount=%lu",
          inError.localizedDescription,
          (long)inError.code,
          inRequest.sessionInfo,
          (long)retryCount);
    /* TODO
     HANDLE THIS     ERROR flickrAPIRequest failed The operation couldn’t be completed. Request timeout (code=2147418114)
     end
     
     */
    switch (inError.code) {
        case OFFlickrAPIRequestConnectionError:
            // NSLog(@"OFFlickrAPIRequestConnectionError");
            break;
        case OFFlickrAPIRequestTimeoutError:
            // NSLog(@"OFFlickrAPIRequestTimeoutError");
            break;
        case OFFlickrAPIRequestFaultyXMLResponseError:
            // NSLog(@"OFFlickrAPIRequestFaultyXMLResponseError");
            break;
        case OFFlickrAPIRequestOAuthError:
            // NSLog(@"OFFlickrAPIRequestOAuthError");
            return NO; /* We return because retrying this one isn't going to fix anything. */
            break;
        default:
            break;
    }
    if (inRequest.sessionInfo)
    {
        return [_requestPool canRetry: inRequest];
    }
    return NO;
    
}

- (void)flickrAPIRequest: (OFFlickrAPIRequest *)inRequest
        didFailWithError: (NSError *)inError
{
    if ([self trackFailedAPIRequest: inRequest
                              error: inError])
    {
        NSArray *pieces = [inRequest.sessionInfo componentsSeparatedByString: @";"];
        if ([inRequest.sessionInfo hasPrefix: @"fetchExif;"])
        {
            [self fetchExifUsingPhotoId: pieces[1] secret: pieces[2]]; /* Retry */
        }
        else if ([inRequest.sessionInfo hasPrefix: @"fetchInfo;"])
        {
            [self fetchInfoUsingPhotoId: pieces[1] secret: pieces[2]]; /* Retry */
        }
        else  if ([inRequest.sessionInfo hasPrefix: @"nextPhoto"])
        {
            [self nextPhoto]; /* Retry */
        }
        else  if ([inRequest.sessionInfo hasPrefix: @"deleteNote;"])
        {
            [self deleteNote: pieces[1]]; /* Retry */
        }
        
        else  if ([inRequest.sessionInfo hasPrefix: @"addNote;"])
        {
            @throw [NSException exceptionWithName: @"Unimplemented"
                                           reason: @"Recovery from failure during note addition is unimplemented"
                                         userInfo: nil];
            [self addFaceNoteTo: pieces[1] face: pieces[2]]; /* Retry */
        }
        else
        {
            // TODO Add method to restart intialization; have MMPhoto also call that.
            self.initializationProgress = -1.0;
        }
        
    }
/* NEED TO FIGURE OUT WHICH REQUEST FAILED : initialization, reset to 0/-1 and retry that */
/* ANSWER: Set and check sessionInfo element to track a given request. */

/*    else if (OFFlickrAPIRequestOAuthError) need to re-send to initialization or push that information back upstream.
    {

*/
}

- (NSURL *)urlFromDictionary: (NSDictionary *) photoDict
{
    return [_flickrContext photoSourceURLFromDictionary: photoDict size: OFFlickrSmallSize];
}
@end
