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

#pragma mark Public Methods

- (id) initAndStartAuthorization: (ProgresBlockType) progressBlock
{
    _progressBlock = progressBlock;
    // Register to receive the callback URL
    [[NSAppleEventManager sharedAppleEventManager] setEventHandler: self
                                                       andSelector: @selector(handleIncomingURL:withReplyEvent:)
                                                     forEventClass: kInternetEventClass
                                                        andEventID: kAEGetURL];
    [self doOauthDance: nil];
    return self;
}

- (id) initWithStoredToken: (NSString *) token
                    secret: (NSString *) secret;
{
    _accessToken = token;
    _tokenSecret = secret;
    return self;
}

- (NSURLRequest *)apiRequest: (NSString *)api
                  parameters: (NSDictionary *)parameters
                        verb: (NSString *)verb
{
    NSString *path = [NSString stringWithFormat: @"/api/v2/%@", api]; // e.g., "album/4RTMrj"
    return [TDOAuth URLRequestForPath: path
                           parameters: parameters
                                 host: SMUGMUG_ENDPOINT
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
    _initializationStatusString = nil;
    _progressBlock = nil;
    _tokenSecret = nil;
}

#pragma mark Private Methods

- (void)doOauthDance: (NSDictionary *)params;
{
    NSDictionary *requestSettings;
    void (^specificCompletionAction)(NSData *result);
    if (!params)
    {
        [self updateState: 0.0 asText: @"Unitialized"];
        _accessToken = nil;
        _tokenSecret = nil;
        requestSettings = @{
                            @"url":         @"/services/oauth/1.0a/getRequestToken",
                            @"parameters":  @{@"oauth_callback": @"mugmover://smugmug"}
                           };
        specificCompletionAction = ^(NSData *result){
            NSString *responseString = [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];
            // Conveniently, the unparsed response in this case is ready to be used, as it's like
            // oauth_token=foo&oauth_token_secret=bar
            
            NSString *authUrlString = [NSString stringWithFormat: @"%@://%@/services/oauth/1.0a/authorize?Permissions=Modify&Access=Full&%@",
                                       SMUGMUG_SCHEME, SMUGMUG_ENDPOINT, responseString];
            NSURL *authUrl = [NSURL URLWithString: authUrlString];
            [self updateState: 0.4 asText: @"Request user authorization (step 2/5)"];
            [[NSWorkspace sharedWorkspace] openURL: authUrl];
        };
        [self updateState: 0.2 asText: @"Get the OAuth request token (step 1/5)"];
    }
    else
    {
        requestSettings = @{
                            @"url":         @"/services/oauth/1.0a/getAccessToken",
                            @"parameters":  @{@"oauth_verifier": [params objectForKey: @"oauth_verifier"]},
                            @"accesstoken": [params objectForKey: @"oauth_token"],
                            @"tokensecret": [params objectForKey: @"oauth_token_secret"],
                           };
        specificCompletionAction = ^(NSData *result){
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
        };
        [self updateState: 0.8 asText: @"Get the OAuth access token (step 4/5)"];
    }
    NSURLRequest *request =  [TDOAuth URLRequestForPath: [requestSettings objectForKey: @"url"]
                                             parameters: [requestSettings objectForKey: @"parameters"]
                                                   host: SMUGMUG_ENDPOINT
                                            consumerKey: MUGMOVER_SMUGMUG_API_KEY_MACRO
                                         consumerSecret: MUGMOVER_SMUGMUG_SHARED_SECRET_MACRO
                                            accessToken: [requestSettings objectForKey: @"accesstoken"]
                                            tokenSecret: [requestSettings objectForKey: @"tokensecret"]
                                                 scheme: SMUGMUG_SCHEME
                                          requestMethod: @"GET"
                                           dataEncoding:TDOAuthContentTypeJsonObject
                                           headerValues: @{@"Accept": @"application/json"}
                                        signatureMethod: TDOAuthSignatureMethodHmacSha1];

    if (request)
    {
        [NSURLConnection sendAsynchronousRequest: request
                                           queue: [NSOperationQueue currentQueue]
                               completionHandler:  ^(NSURLResponse *response, NSData *result, NSError *error)
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
                         specificCompletionAction(result);
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

- (NSMutableDictionary *) extractQueryParams: (NSString *) urlAsString
{
    NSArray *pieces = [urlAsString componentsSeparatedByString:@"?"];
    
    if ([pieces count] != 2)
    {
        return nil; // signals a problem
    }
    return [self splitQueryParams: [pieces objectAtIndex: 1]];
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
        [self doOauthDance: params];
    }
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

- (void) updateState: (float) state
              asText: (NSString *) text
{
    DDLogInfo(@"OAUTH %2.1f %@", state, text);
    _initializationStatusValue = state;
    _initializationStatusString = text;
    if (_progressBlock)
    {
        _progressBlock(state, text);
    }
}

@end
