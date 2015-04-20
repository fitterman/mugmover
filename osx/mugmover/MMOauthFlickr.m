//
//  MMOauthFlickr
//  mugmover
//
//  Created by Bob Fitterman on 3/24/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMOauthAbstract.h"
#import "MMOauthFlickr.h"

#define SERVICE_SCHEME      @"https"
#define SERVICE_ENDPOINT    @"www.flickr.com"

@implementation MMOauthFlickr

#pragma mark Public Methods

- (NSURLRequest *)apiRequest: (NSString *)api
                  parameters: (NSDictionary *)parameters
                        verb: (NSString *)verb
{
    NSMutableDictionary *mergedParams = [parameters mutableCopy];
    [mergedParams setObject: api forKey: @"method"];
    [mergedParams setObject: @"json" forKey: @"format"];
    [mergedParams setObject: @"1" forKey: @"nojsoncallback"];
    return [TDOAuth URLRequestForPath: @"/services/rest/"
                           parameters: mergedParams
                                 host: SERVICE_ENDPOINT
                          consumerKey: MUGMOVER_FLICKR_API_KEY_MACRO
                       consumerSecret: MUGMOVER_FLICKR_SHARED_SECRET_MACRO
                          accessToken: self.accessToken
                          tokenSecret: self.tokenSecret
                               scheme: SERVICE_SCHEME
                        requestMethod: verb
                         dataEncoding: TDOAuthContentTypeJsonObject
                         headerValues: @{@"Accept": @"application/json"}
                      signatureMethod: TDOAuthSignatureMethodHmacSha1];
}

#pragma mark Private Methods

- (void)doOauthDance: (NSDictionary *)params;
{
    NSDictionary *requestSettings;
    void (^specificCompletionAction)(NSData *result);
    if (!params)
    {
        [self updateState: 0.0 asText: @"Unitialized"];
        self.accessToken = nil;
        self.tokenSecret = nil;
        requestSettings = @{
                            @"url":         @"/services/oauth/request_token",
                            @"parameters":  @{@"oauth_callback": @"mugmover://flickr"}
                           };
        specificCompletionAction = ^(NSData *result){
            NSString *responseString = [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];
            // Conveniently, the unparsed response in this case is ready to be used, as it's like
            // "oauth_token=foo&oauth_token_secret=bar" but we have to save the oauth_token_secret
            // for later use.
            _interimTokenSecret = [[self splitQueryParams:responseString] objectForKey: @"oauth_token_secret"];


            
            NSString *authUrlString = [NSString stringWithFormat: @"%@://%@/services/oauth/authorize?%@",
                                       SERVICE_SCHEME, SERVICE_ENDPOINT, responseString];
            NSURL *authUrl = [NSURL URLWithString: authUrlString];
            [self updateState: 0.4 asText: @"Request user authorization (step 2/5)"];
            [[NSWorkspace sharedWorkspace] openURL: authUrl];
        };
        [self updateState: 0.2 asText: @"Get the OAuth request token (step 1/5)"];
    }
    else
    {
        requestSettings = @{
                            @"url":         @"/services/oauth/access_token",
                            @"parameters":  @{@"oauth_verifier": [params objectForKey: @"oauth_verifier"]},
                            @"accesstoken": [params objectForKey: @"oauth_token"],
                            @"tokensecret": _interimTokenSecret,
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
                self.accessToken = [params objectForKey: @"oauth_token"];
                self.tokenSecret = [params objectForKey: @"oauth_token_secret"];
                [self updateState: 1.0 asText: @"Successfully initialized"];
            }
        };
        [self updateState: 0.8 asText: @"Get the OAuth access token (step 4/5)"];
    }
    NSURLRequest *request =  [TDOAuth URLRequestForPath: [requestSettings objectForKey: @"url"]
                                             parameters: [requestSettings objectForKey: @"parameters"]
                                                   host: SERVICE_ENDPOINT
                                            consumerKey: MUGMOVER_FLICKR_API_KEY_MACRO
                                         consumerSecret: MUGMOVER_FLICKR_SHARED_SECRET_MACRO
                                            accessToken: [requestSettings objectForKey: @"accesstoken"]
                                            tokenSecret: [requestSettings objectForKey: @"tokensecret"]
                                                 scheme: SERVICE_SCHEME
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
                 if ([httpResponse statusCode] >= 400) // These are errors (300 is handled automatically)
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

- (void) close
{
    _interimTokenSecret = nil;
    [super close];
}
@end
