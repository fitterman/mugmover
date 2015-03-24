//
//  MMSmugmugOauth.m
//  mugmover
//
//  Created by Bob Fitterman on 3/24/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMSmugmugOauth.h"

#define SMUGMUG_SCHEME      @"https"
#define SMUGMUG_ENDPOINT    @"secure.smugmug.com"

@implementation MMSmugmugOauth

- (id) initAndStartAuthorization
{
    [self updateState: 0.0 asText: @"Unitialized"];
    [self getRequestToken];
    return self;
}

- (void) updateState: (float) state
              asText: (NSString *) text
{
    
    _initializationStatusValue = state;
    _initializationStatusString = text;
}

- (void)getRequestToken;
{
    // Register to receive the callback URL
    [[NSAppleEventManager sharedAppleEventManager] setEventHandler: self
                                                       andSelector: @selector(handleIncomingURL:withReplyEvent:)
                                                     forEventClass: kInternetEventClass
                                                        andEventID: kAEGetURL];
    NSURLRequest *request =  [TDOAuth URLRequestForPath: @"/services/oauth/1.0a/getRequestToken"
                                             parameters: @{@"oauth_callback": @"mugmover://smugmug"}
                                                   host: SMUGMUG_ENDPOINT
                                            consumerKey: MUGMOVER_SMUGMUG_API_KEY_MACRO
                                         consumerSecret: MUGMOVER_SMUGMUG_SHARED_SECRET_MACRO
                                            accessToken: nil
                                            tokenSecret: nil
                                                 scheme: SMUGMUG_SCHEME
                                          requestMethod: @"GET"
                                           dataEncoding:TDOAuthContentTypeJsonObject
                                           headerValues: @{@"Accept": @"application/json"}
                                        signatureMethod: TDOAuthSignatureMethodHmacSha1];
    
    if (request)
    {
        [self updateState: 0.2 asText: @"Get the OAuth request token (step 1/5)"];
        [NSURLConnection sendAsynchronousRequest: request
                                           queue: [NSOperationQueue currentQueue]
                               completionHandler: ^(NSURLResponse *response,
                                                    NSData *result,
                                                    NSError *error)
         {
             if (error)
             {
                 [self updateState: -1.0 asText: [NSString stringWithFormat: @"System error: %@", error]];
             }
             else
             {
                 NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                 if ([httpResponse statusCode] != 200)
                 {
                    [self updateState: -1.0 asText: [NSString stringWithFormat: @"Network error httpStatusCode=%ld", (long)[httpResponse statusCode]]];
                 }
                 else
                 {
                     if ([result length] > 0)
                     {
                         NSString *responseString = [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];
                         // Conveniently, the unparsed response in this case is ready to be used, as it's like
                         // oauth_token=foo&oauth_token_secret=bar
                         
                         NSString *authUrlString = [NSString stringWithFormat: @"%@://%@/services/oauth/1.0a/authorize?Permissions=Modify&Access=Full&%@",
                                                                                SMUGMUG_SCHEME, SMUGMUG_ENDPOINT, responseString];
                         NSURL *authUrl = [NSURL URLWithString: authUrlString];
                         [self updateState: 0.4 asText: @"Request user authorization (step 2/5)"];
                         [[NSWorkspace sharedWorkspace] openURL: authUrl];
                     }
                     else
                     {
                         [self updateState: -1.0 asText: @"No data received"];
                     }
                 }
             }
         }];
    }
}
- (void) getAccessTokenWithParams: (NSDictionary *) params
{
    [self updateState: 0.8 asText: @"Get the OAuth access token (step 4/5)"];
    NSURLRequest *request =  [TDOAuth URLRequestForPath: @"/services/oauth/1.0a/getAccessToken"
                                             parameters: @{@"oauth_verifier": [params objectForKey: @"oauth_verifier"]}
                                                   host: SMUGMUG_ENDPOINT
                                            consumerKey: MUGMOVER_SMUGMUG_API_KEY_MACRO
                                         consumerSecret: MUGMOVER_SMUGMUG_SHARED_SECRET_MACRO
                                            accessToken: [params objectForKey: @"oauth_token"]
                                            tokenSecret: [params objectForKey: @"oauth_token_secret"]
                                                 scheme: SMUGMUG_SCHEME
                                          requestMethod: @"GET"
                                           dataEncoding:TDOAuthContentTypeJsonObject
                                           headerValues: @{@"Accept": @"application/json"}
                                        signatureMethod: TDOAuthSignatureMethodHmacSha1];
    
    // Make the request
    [NSURLConnection sendAsynchronousRequest: request
                                       queue: [NSOperationQueue currentQueue]
                           completionHandler: ^(NSURLResponse *response,
                                                NSData *result,
                                                NSError *error)
     {
         if (error)
         {
             [self updateState: -1.0 asText: [NSString stringWithFormat: @"System error: %@", error]];
         }
         else
         {
             NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
             if ([httpResponse statusCode] != 200)
             {
                 [self updateState: -1.0 asText: [NSString stringWithFormat: @"Network error httpStatusCode=%ld", (long)[httpResponse statusCode]]];
             }
             else
             {
                 if ([result length] > 0)
                 {
                     NSString *response = [[NSString alloc] initWithData: result encoding: NSUTF8StringEncoding];
                     NSDictionary *params = [self splitQueryParams: response];
                     if (!params)
                     {
                         [self updateState: -1.0 asText: @"Unable to parse response"];
                     }
                     else
                     {
                         _accessToken = [params objectForKey: @"oauth_token"];
                         _tokenSecret = [params objectForKey: @"oauth_token_secret"];
                         [self updateState: 1.0 asText: @"Successfully initialized"];
                     }
                 }
                 else
                 {
                     [self updateState: -1.0 asText: @"No data received"];
                 }
             }
         }
     }];
}

- (NSURLRequest *)apiRequest: (NSString *)api
                  parameters: (NSDictionary *)parameters
                        verb: (NSString *)verb
{
    NSString *path = [NSString stringWithFormat: @"/api/v2/%@", api]; // e.g., "album/4RTMrj"
    return [TDOAuth URLRequestForPath: path
                           parameters: parameters
                                 host: @"secure.smugmug.com"
                          consumerKey: MUGMOVER_SMUGMUG_API_KEY_MACRO
                       consumerSecret: MUGMOVER_SMUGMUG_SHARED_SECRET_MACRO
                          accessToken: _accessToken
                          tokenSecret: _tokenSecret
                               scheme: SMUGMUG_SCHEME
                        requestMethod: verb
                         dataEncoding: TDOAuthContentTypeJsonObject
                         headerValues: @{@"Accept": @"application/json"}
                      signatureMethod: TDOAuthSignatureMethodHmacSha1];
}

- (void) close
{
    _accessToken = nil;
    _tokenSecret = nil;
    _initializationStatusString = nil;
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
    
    NSString *callbackUrlString = [[event paramDescriptorForKeyword: keyDirectObject] stringValue];
    NSDictionary *params = [self extractQueryParams: callbackUrlString];
    if (!params)
    {
        [self updateState: -1.0 asText: @"Unable to parse callback URL"];
    }
    else
    {
        [self updateState: 0.6 asText: @"Server returned request token (step 3/5)"];
        [self getAccessTokenWithParams: params];
    }
}


@end
