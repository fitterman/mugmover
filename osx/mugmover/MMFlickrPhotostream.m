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
            return nil;
        }
        
        _photoDictionary = [[NSMutableDictionary alloc] init];
        if (!_photoDictionary)
        {
            _library = nil;
            return nil;
        }
        self.handle = flickrHandle;
        _page = 1;
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
    _flickrContext = nil;
    _handle = nil;
    _library = nil;
    _photoDictionary = nil;
    _streamQueue = nil;
}

-   (void) flickrAPIRequest: (OFFlickrAPIRequest *) inRequest
 didObtainOAuthRequestToken: (NSString *) inRequestToken
                     secret: (NSString *) inSecret
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

- (void) handleIncomingURL: (NSAppleEventDescriptor *) event
            withReplyEvent: (NSAppleEventDescriptor *) replyEvent
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

-      (void) flickrAPIRequest: (OFFlickrAPIRequest *) inRequest
     didObtainOAuthAccessToken: (NSString *) inAccessToken
                        secret: (NSString *) inSecret
                  userFullName: (NSString *) inFullName
                      userName: (NSString *) inUserName
                      userNSID: (NSString *) inNSID
{
     // NSLog(@"STEP 5 You're in. Save the access token");
     // NSLog(@"       request=%@", inRequest);
     // NSLog(@"       accessToken=%@", inAccessToken);
     // NSLog(@"       inSecret=%@", inSecret);
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

- (void) getPhotos
{
    NSString *userId = @"127850168@N06"; // TODO Don't hardcode this
    
    OFFlickrAPIRequest *flickrRequest = [_requestPool getRequestFromPoolSettingDelegate: self];
    if ([flickrRequest isRunning])
    {
        @throw [NSException exceptionWithName: @"PoolManagement"
                                       reason: @"Pool request is still running"
                                     userInfo: nil];

    }
    NSBlockOperation *getPhotosOperation = [NSBlockOperation blockOperationWithBlock:^
                                            {
                                                flickrRequest.sessionInfo = @"getPhotos";
                                                [flickrRequest callAPIMethodWithGET: @"flickr.people.getPhotos"
                                                                          arguments: @{@"per_page": @"16",
                                                                                       @"page": [NSString stringWithFormat: @"%ld", _page],
                                                                                       @"user_id": userId
                                                                                       }];
                                            }];
    [self.streamQueue addOperation: getPhotosOperation];
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

#pragma mark ObjectiveFlickr delegate methods

- (void) flickrAPIRequest: (OFFlickrAPIRequest *) inRequest
  didCompleteWithResponse: (NSDictionary *) inResponseDictionary
{
    NSLog(@"  COMPLETION: request=%@", inRequest.sessionInfo);
    if ([inRequest.sessionInfo isEqualToString: @"getPhotos"])
    {
        photoResponseDictionary = inResponseDictionary;
        if (!self.photosInStream)
        {
            _photosInStream = [[photoResponseDictionary valueForKeyPath: @"photos.total"] integerValue];
        }
        NSArray *photos =[photoResponseDictionary valueForKeyPath: @"photos.photo"];
        // If you get an empty buffer back, that means there are no more photos to be had: quit trying
        if ((!photos) || ([photos count] == 0))
        {
            NSLog(@"END OF STREAM");
        }
        for (NSDictionary *photoToBeReturned in photos)
        {
            MMPhoto *photo = [[MMPhoto alloc] initWithFlickrDictionary: photoToBeReturned
                                                                stream: self];
            NSString *photoKey = [NSString stringWithFormat: @"%lx", (NSInteger)(photo)];
            [_photoDictionary setObject: photo forKey: photoKey];

            NSBlockOperation *returnPhoto = [NSBlockOperation blockOperationWithBlock:^
                                                 {
                                                     // // NSLog (@"  BLOCK returning photo with exif");
                                                     NSLog(@"%lu/%lu", (long)_currentPhotoIndex + 1, (long)_photosInStream);
                                                     [photo performNextStep];
                                                 }
                                             ];
            [self.streamQueue addOperation: returnPhoto];
        }
    }
}

- (BOOL) trackFailedAPIRequest: (OFFlickrAPIRequest *) inRequest
                         error: (NSError *) inError
{
    NSLog(@"ERROR flickrAPIRequest failed %@ (code=%lx), sessionInfo=\"%@\" retryCount=%lu",
          inError.localizedDescription,
          (long) inError.code,
          inRequest.sessionInfo,
          (long) retryCount);
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

- (void) flickrAPIRequest: (OFFlickrAPIRequest *) inRequest
         didFailWithError: (NSError *) inError
{
    if ([self trackFailedAPIRequest: inRequest
                              error: inError])
    {
        if ([inRequest.sessionInfo isEqualToString: @"getPhotos"])
        {
            [self getPhotos]; /* Retry */
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

- (NSURL *) urlFromDictionary: (NSDictionary *) photoDict
{
    return [_flickrContext photoSourceURLFromDictionary: photoDict size: OFFlickrSmallSize];
}
@end
