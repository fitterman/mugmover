
//
//  MMSmugmug.m
//  Everything to do with Smugmug integration.
//
//  Created by Bob Fitterman on 03/17/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMPhoto.h"
#import "MMPhotoLibrary.h"
#import "MMSmugmug.h"

#import "TDOAuth.h" // see http://stackoverflow.com/questions/15930628/implementing-oauth-1-0-in-an-ios-app

@implementation MMSmugmug


#define PHOTOS_PER_REQUEST (10)

NSDictionary       *photoResponseDictionary;
long                retryCount;

- (id) initWithHandle: (NSString *) handle
          libraryPath: (NSString *) libraryPath
{
    self = [self init];
    if (self)
    {
        if (!handle || !libraryPath)
        {
            return nil;
        }
        _library = [[MMPhotoLibrary alloc] initWithPath: (NSString *) libraryPath];
        if (!_library)
        {
            [self releaseStrongPointers];
            return nil;
        }

        _photoDictionary = [[NSMutableDictionary alloc] init];
        if (!_photoDictionary)
        {
            [self releaseStrongPointers];
            return nil;
        }
        _handle = handle;
        _currentPhotoIndex = (_page - 1) * PHOTOS_PER_REQUEST;
        self.initializationProgress = 0.0;
        
        // set up the OAuth callback handler
        [[NSAppleEventManager sharedAppleEventManager] setEventHandler: self
                                                           andSelector: @selector(handleIncomingURL:withReplyEvent:)
                                                         forEventClass: kInternetEventClass
                                                            andEventID: kAEGetURL];
        

        // Demo
        
        // with additional params
        DDLogInfo(@"STEP 1 Initiate the Oauth Request");
        
        NSURLRequest *request = [TDOAuth URLRequestForPath: @"/services/oauth/1.0a/getRequestToken"
                                             GETParameters: @{@"oauth_callback": @"mugmover://smugmug"}
                                                    scheme: @"https"
                                                      host: @"secure.smugmug.com"
                                               consumerKey: MUGMOVER_SMUGMUG_API_KEY_MACRO
                                            consumerSecret: MUGMOVER_SMUGMUG_SHARED_SECRET_MACRO
                                               accessToken: nil
                                               tokenSecret: nil];
        // make the request
        [NSURLConnection sendAsynchronousRequest: request
                                           queue: [NSOperationQueue currentQueue]
                               completionHandler: ^(NSURLResponse *response,
                                                    NSData *result,
                                                    NSError *error)
         {
             if ([result length] > 0)
             {
                 NSString *s = [[NSString alloc] initWithData: result
                                                     encoding: NSUTF8StringEncoding];
                 
                 //parse result
                 NSLog(@"response=%@", s);
             }
             
             NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
             if (error)
             {
                 DDLogError(@"error=%@", error);
             }
             else if ([httpResponse statusCode] != 200)
             {
                 
             }
             else
             {
                 if ([result length] > 0)
                 {
                     NSString *responseString = [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];
                     NSLog(@"response=%@", responseString);
                     // Conveniently, the unparsed response in this case is ready to be used, as it's like
                     // oauth_token=foo&oauth_token_secret=bar
                     
                     NSString *authUrlString = [NSString stringWithFormat: @"https://secure.smugmug.com/services/oauth/1.0a/authorize?Permissions=Modify&Access=Full&%@", responseString];
                     NSURL *authUrl = [NSURL URLWithString: authUrlString];
                     [[NSWorkspace sharedWorkspace] openURL: authUrl];
                 }
                 else
                 {
                     DDLogError(@"no data downloaded");
                 }
             }
         }];
        
    }
    return self;
}

- (void) close
{
    _accessSecret = nil;
    _accessToken = nil;
    _handle = nil;
    _library = nil;
    _photoDictionary = nil;
    _streamQueue = nil;
}

- (void) releaseStrongPointers
{
    if (_library)
    {
        [_library close];
    }
    _accessSecret = nil;
    _accessToken = nil;
    _currentPhoto = nil;
    _handle = nil;
    _library = nil;
    _photoDictionary = nil;
    _streamQueue = nil;
}

- (NSMutableDictionary *) extractQueryParams: (NSString *) urlAsString
{
    NSArray *pieces = [urlAsString componentsSeparatedByString:@"?"];
    
    if ([pieces count] != 2)
    {
        return nil; // signals a problem
    }
    return [self splitQueryParams: [pieces objectAtIndex: 1]];
}

- (NSMutableDictionary *) splitQueryParams: (NSString *) inString
{
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    NSArray *params = [inString componentsSeparatedByString:@"&"];
    for (NSString *param in params)
    {
        NSArray *kv = [param componentsSeparatedByString:@"="];
        if ([kv count] != 2) {
            return nil;
        }
        [result setObject:[kv objectAtIndex:1] forKey:[kv objectAtIndex:0]];
    }
    return result;
}

- (void) handleIncomingURL: (NSAppleEventDescriptor *) event
            withReplyEvent: (NSAppleEventDescriptor *) replyEvent
{
    DDLogInfo(@"STEP 2 Handle incoming (mugmover) URL");
    self.initializationProgress = 0.6; /* That's 3 out of 5 steps */
    
    NSString *callbackUrlString = [[event paramDescriptorForKeyword: keyDirectObject] stringValue];
    DDLogInfo(@"       callbackURL=%@", callbackUrlString);

    NSDictionary *params = [self extractQueryParams: callbackUrlString];
    NSURLRequest *request;
    if (!params)
    {
        DDLogError(@"Invalid callback URL");
        self.initializationProgress = -1.0;
    }
    else
    {
        NSLog(@"%@", params);
        self.initializationProgress = 0.6; /* That's 3 out of 5 steps */
        request = [TDOAuth URLRequestForPath: @"/services/oauth/1.0a/getAccessToken"
                               GETParameters: @{
                                                @"oauth_callback": @"mugmover://smugmug",
                                                @"oauth_verifier": [params objectForKey: @"oauth_verifier"],
                                               }
                                      scheme: @"https"
                                        host: @"secure.smugmug.com"
                                 consumerKey: MUGMOVER_SMUGMUG_API_KEY_MACRO
                              consumerSecret: MUGMOVER_SMUGMUG_SHARED_SECRET_MACRO
                                 accessToken: [params objectForKey: @"oauth_token"]
                                 tokenSecret: [params objectForKey: @"oauth_token_secret"]];
        [self logUrlRequest:request];
        // Make the request
        [NSURLConnection sendAsynchronousRequest: request
                                           queue: [NSOperationQueue currentQueue]
                               completionHandler: ^(NSURLResponse *response,
                                                    NSData *result,
                                                    NSError *error)
                                                     {
                                                         if ([result length] > 0)
                                                         {
                                                             NSString *s = [[NSString alloc] initWithData: result encoding: NSUTF8StringEncoding];
                                                             //parse result
                                                             NSLog(@"response=%@", s);
                                                         }

                                                         NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                                                         if (error)
                                                         {
                                                             DDLogError(@"error=%@", error);
                                                         }
                                                         else if ([httpResponse statusCode] != 200)
                                                         {
                                                             
                                                         }
                                                         else
                                                         {
                                                            if ([result length] > 0)
                                                            {
                                                                NSString *response = [[NSString alloc] initWithData: result encoding: NSUTF8StringEncoding];
                                                                DDLogInfo(@"       response=%@", response);
                                                                
                                                                NSDictionary *params = [self splitQueryParams: response];
                                                                if (!params)
                                                                {
                                                                    DDLogError(@"Invalid callback URL");
                                                                    self.initializationProgress = -1.0;
                                                                }
                                                                else
                                                                {
                                                                    NSLog(@"params=%@", params);
                                                                    _accessToken = [params objectForKey: @"oauth_token"];
                                                                    _tokenSecret = [params objectForKey: @"oauth_token_secret"];
                                                                    
                                                                    self.initializationProgress = 0.8; /* That's 4 out of 5 steps */
                                                                    NSURLRequest *request;
                                                                    request = [TDOAuth URLRequestForPath: @"/api/v2/album/4RTMrj"
                                                                                                            parameters: nil
                                                                                                                  host: @"secure.smugmug.com"
                                                                                                           consumerKey: MUGMOVER_SMUGMUG_API_KEY_MACRO
                                                                                                        consumerSecret: MUGMOVER_SMUGMUG_SHARED_SECRET_MACRO
                                                                                                           accessToken: _accessToken
                                                                                                           tokenSecret: _tokenSecret
                                                                                                                scheme: @"https"
                                                                                                         requestMethod: @"GET"
                                                                                                          dataEncoding:TDOAuthContentTypeJsonObject
                                                                                                          headerValues: @{@"Accept": @"application/json"}
                                                                                                       signatureMethod: TDOAuthSignatureMethodHmacSha1];
                                                                    NSURLResponse* response;
                                                                    NSError* error = nil;
  /*                                                                  NSData* result = [NSURLConnection sendSynchronousRequest: request
                                                                                                           returningResponse: &response
                                                                                                                       error: &error];
                                                                    if (!error)
                                                                    {
                                                                        NSString *s = [[NSString alloc] initWithData: result encoding: NSUTF8StringEncoding];
                                                                        //parse result
                                                                        NSLog(@"response=%@", s);
                                                                    }

                                                                    request = [TDOAuth URLRequestForPath: @"/api/v2/album/4RTMrj"
                                                                                              POSTParameters: @{@"Name": @"My New Title"}
                                                                                                    host: @"secure.smugmug.com"
                                                                                             consumerKey: MUGMOVER_SMUGMUG_API_KEY_MACRO
                                                                                          consumerSecret: MUGMOVER_SMUGMUG_SHARED_SECRET_MACRO
                                                                                             accessToken: _accessToken
                                                                                             tokenSecret: _tokenSecret];
    */
                                                                 request = [TDOAuth URLRequestForPath: @"/api/v2/album/4RTMrj"
                                                                                           parameters: @{@"Name": @"My New Title", @"_method": @"PATCH"}
                                                                                                 host: @"secure.smugmug.com"
                                                                                          consumerKey: MUGMOVER_SMUGMUG_API_KEY_MACRO
                                                                                       consumerSecret: MUGMOVER_SMUGMUG_SHARED_SECRET_MACRO
                                                                                          accessToken: _accessToken
                                                                                          tokenSecret: _tokenSecret
                                                                                               scheme:@"https"
                                                                                        requestMethod:@"POST"
                                                                                         dataEncoding:TDOAuthContentTypeJsonObject
                                                                                         headerValues:@{@"Accept": @"application/json"}
                                                                                      signatureMethod:TDOAuthSignatureMethodHmacSha1];

/*                                                                    request = [TDOAuth URLRequestForPath: @"/api/v2/album/4RTMrj"
                                                                                              parameters: @{@"Name": @"My New Title"}
                                                                                                    host: @"secure.smugmug.com"
                                                                                             consumerKey: MUGMOVER_SMUGMUG_API_KEY_MACRO
                                                                                          consumerSecret: MUGMOVER_SMUGMUG_SHARED_SECRET_MACRO
                                                                                             accessToken: _accessToken
                                                                                             tokenSecret: _tokenSecret
                                                                                                  scheme: @"https"
                                                                                                  method: @"PATCH"
                                                                                            headerValues: @{@"Accept": @"application/json"}
                                                                                         signatureMethod: TDOAuthSignatureMethodHmacSha1];
*/ /*
                                                                    request = [TDOAuth URLRequestForPath: @"/api/v2/album/4RTMrj"
                                                                                                            parameters: @{@"Name": @"My New Title"}
                                                                                                                  host: @"secure.smugmug.com"
                                                                                                           consumerKey: MUGMOVER_SMUGMUG_API_KEY_MACRO
                                                                                                        consumerSecret: MUGMOVER_SMUGMUG_SHARED_SECRET_MACRO
                                                                                                           accessToken: _accessToken
                                                                                                           tokenSecret: _tokenSecret
                                                                                                                scheme: @"https"
                                                                                                                method: @"PATCH"
                                                                                                          headerValues: @{@"Accept": @"application/json"}
                                                                                                       signatureMethod: TDOAuthSignatureMethodHmacSha1];*/
                                                                    result = [NSURLConnection sendSynchronousRequest: request
                                                                                                           returningResponse: &response
                                                                                                                       error: &error];
                                                                    //if (!error)
                                                                    {
                                                                        NSString *s = [[NSString alloc] initWithData: result encoding: NSUTF8StringEncoding];
                                                                        //parse result
                                                                        NSLog(@"response=%@", s);
                                                                    }
                                                                    

                                                                }
                                                            }
                                                            else
                                                            {
                                                                DDLogError(@"no data downloaded");
                                                            }
                                                         }
                                                     }];
        
    }
}

- (NSString*) logUrlRequest: (NSURLRequest *) urlRequest
{
    NSString *requestPath = [[urlRequest URL] absoluteString];
    DDLogInfo(@"requestPath=%@", requestPath);
    DDLogInfo(@"headers=%@", [urlRequest allHTTPHeaderFields]);
    return requestPath;
}

@end
