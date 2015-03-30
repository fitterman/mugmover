//
//  MMOauthSmugmug.m
//  mugmover
//
//  Created by Bob Fitterman on 3/24/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMOauthSmugmug.h"

#define SERVICE_SCHEME      @"https"
#define SERVICE_ENDPOINT    @"secure.smugmug.com"
#define UPLOAD_SCHEME       @"http"
#define UPLOAD_ENDPOINT     @"upload.smugmug.com"

@implementation MMOauthSmugmug
@synthesize accessToken=_accessToken;
@synthesize tokenSecret=_tokenSecret;
@synthesize progressBlock=_progressBlock;

#pragma mark Public Methods

/**
 Prepares a JSON request for information _from_ the server. (There is a separate method for
 the upload API.) It is up to the caller to actually make the call using a method such as
 [NSURLConnection sendAsynchronousRequest:queue:completionHandler].
 +api+ is something like @"album/4RTMrj"
 +parameters+ is a dictionary of key-value pairs which will turn into a JSON structure. Each
 key should be a documented key for the particular api call being made.
 +verb+ is the request method, e.g. @"POST" or "@PATCH" or @"GET"
 */
- (NSURLRequest *)apiRequest: (NSString *)api
                  parameters: (NSDictionary *)parameters
                        verb: (NSString *)verb
{
    return [TDOAuth URLRequestForPath: [NSString stringWithFormat: @"/api/v2/%@", api]
                           parameters: parameters
                                 host: SERVICE_ENDPOINT
                          consumerKey: MUGMOVER_SMUGMUG_API_KEY_MACRO
                       consumerSecret: MUGMOVER_SMUGMUG_SHARED_SECRET_MACRO
                          accessToken: _accessToken
                          tokenSecret: _tokenSecret
                               scheme: SERVICE_SCHEME
                        requestMethod: verb
                         dataEncoding: TDOAuthContentTypeJsonObject
                         headerValues: @{@"Accept": @"application/json"}
                      signatureMethod: TDOAuthSignatureMethodHmacSha1];
}

/**
 This prepares a request to upload an image. The caller must then begin the transmission
 of the request to the server.
 +filePath+ should be a fully-qualified path to a local file.
 */
- (NSURLRequest *) upload: (NSString *) filePath
                 albumUid: (NSString *) albumUid // for example, @"4RTMrj"
{
    if (!filePath)
    {
        DDLogError(@"filePath is nil");
        return nil;
    }
    if (!albumUid)
    {
        DDLogError(@"albumUid is nil");
        return nil;
    }
    NSURL* fileUrl = [NSURL fileURLWithPath: filePath];
    if (!fileUrl)
    {
        DDLogError(@"fileUrl is nil");
        return nil;
    }
    // Turn this into a HEAD request so we do not read the data
    NSURLRequest * localRequest = [[NSURLRequest alloc] initWithURL: fileUrl
                                                        cachePolicy: NSURLCacheStorageNotAllowed
                                                    timeoutInterval: 0.0]; // It will not load the data this way
    if (!localRequest)
    {
        DDLogError(@"localRequest is nil");
        return nil;
    }
    NSString *md5 = [MMOauthAbstract md5ForFileAtPath: filePath];
    if (!md5)
    {
        DDLogError(@"Unable to obtain MIME type of local file");
        return nil;
    }
    NSString* mimeType = [MMOauthAbstract mimeTypeForFileAtPath: filePath];
    if (!mimeType)
    {
        DDLogError(@"Unable to obtain MIME type of local file");
        return nil;
    }
    NSError* error = nil;
    unsigned long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:filePath
                                                                                    error: &error] fileSize];
    if (error)
    {
        DDLogError(@"Attempt to obtain local file size returned error %@", error);
        return nil;
    }
    NSInputStream *inputStream = [NSInputStream inputStreamWithFileAtPath: filePath];
    if (!inputStream)
    {
        DDLogError(@"Unable to create stream to local file");
        return nil;
    }
    NSString *albumUri = [NSString stringWithFormat: @"/api/v2/album/%@", albumUid];
    if (!inputStream)
    {
        DDLogError(@"Unable to create stream to local file");
        return nil;
    }
    NSMutableURLRequest *request =  (NSMutableURLRequest *)[TDOAuth URLRequestForPath: @"/"
                                                                           parameters: nil
                                                                                 host: UPLOAD_ENDPOINT
                                                                          consumerKey: MUGMOVER_SMUGMUG_API_KEY_MACRO
                                                                       consumerSecret: MUGMOVER_SMUGMUG_SHARED_SECRET_MACRO
                                                                          accessToken: _accessToken
                                                                          tokenSecret: _tokenSecret
                                                                               scheme: UPLOAD_SCHEME
                                                                        requestMethod: @"POST"
                                                                         dataEncoding: TDOAuthContentTypeJsonObject
                                                                         headerValues: @{@"Accept":                 @"application/json",
                                                                                         @"Content-Length":         [NSString stringWithFormat: @"%llu", fileSize],
                                                                                         @"Content-MD5":            md5,
                                                                                         @"Content-Type":           mimeType,
                                                                                         @"X-Smug-AlbumUri":        albumUri,
                                                                                         @"X-Smug-ResponseType":    @"JSON",
                                                                                         @"X-Smug-Version":         @"v2",
                                                                                         }
                                                                      signatureMethod: TDOAuthSignatureMethodHmacSha1];
    if (!request)
    {
        DDLogError(@"Unable to create request object for upload");
        return nil;
    }
    request.HTTPBodyStream = inputStream;
//    NSData *body = [[NSData alloc] initWithContentsOfFile: filePath];
//    request.HTTPBody = body;
    return request;
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
                                                   host: SERVICE_ENDPOINT
                                            consumerKey: MUGMOVER_SMUGMUG_API_KEY_MACRO
                                         consumerSecret: MUGMOVER_SMUGMUG_SHARED_SECRET_MACRO
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
@end
