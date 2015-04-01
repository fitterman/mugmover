//
//  MMOauthSmugmug.m
//  mugmover
//
//  Created by Bob Fitterman on 3/24/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMOauthAbstract.h"
#import "MMOauthSmugmug.h"

#define SERVICE_SCHEME      @"https"
#define SERVICE_ENDPOINT    @"secure.smugmug.com"
#define UPLOAD_SCHEME       @"http"
#define UPLOAD_ENDPOINT     @"upload.smugmug.com"

@implementation MMOauthSmugmug

extern const NSInteger MMDefaultRetries;

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
    NSMutableDictionary *revisedParameters = [parameters mutableCopy];
    [revisedParameters setObject: @"true" forKey: @"_filteruri"];
    return [TDOAuth URLRequestForPath: [NSString stringWithFormat: @"/api/v2/%@", api]
                           parameters: revisedParameters
                                 host: SERVICE_ENDPOINT
                          consumerKey: MUGMOVER_SMUGMUG_API_KEY_MACRO
                       consumerSecret: MUGMOVER_SMUGMUG_SHARED_SECRET_MACRO
                          accessToken: self.accessToken
                          tokenSecret: self.tokenSecret
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
                    title: (NSString *) title
                  caption: (NSString *) caption
                     tags: (NSArray *) tags

{
    if (!filePath)
    {
        DDLogError(@"filePath is nil");
        return nil;
    }
    NSURL* fileUrl = [NSURL fileURLWithPath: filePath];
    if (!fileUrl)
    {
        DDLogError(@"fileUrl is nil");
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
    NSNumber *length = [MMOauthAbstract lengthForFileAtPath: filePath];
    if (!length)
    {
        DDLogError(@"Unable to obtain length of local file");
        return nil;
    }
    NSInputStream *inputStream = [NSInputStream inputStreamWithFileAtPath: filePath];
    if (!inputStream)
    {
        DDLogError(@"Unable to create stream to local file");
        return nil;
    }

    if (!albumUid)
    {
        DDLogError(@"albumUid is nil");
        return nil;
    }
    NSString *albumUri = [NSString stringWithFormat: @"/api/v2/album/%@", albumUid];

    NSMutableDictionary *headerValues = [[NSMutableDictionary alloc] init];
    if (!headerValues)
    {
        DDLogError(@"Unable to create header dictionary");
        return nil;
    }
    [headerValues setObject: @"application/json" forKey: @"Accept"];
    [headerValues setObject: [NSString stringWithFormat: @"%@", length] forKey: @"Content-Length"];
    [headerValues setObject: md5 forKey: @"Content-MD5"];
    [headerValues setObject: mimeType forKey: @"Content-Type"];
    [headerValues setObject: albumUri forKey: @"X-Smug-AlbumUri"];
    [headerValues setObject: @"JSON" forKey: @"X-Smug-ResponseType"];
    [headerValues setObject: @"v2" forKey: @"X-Smug-Version"];

    NSMutableURLRequest *request =  (NSMutableURLRequest *)[TDOAuth URLRequestForPath: @"/"
                                                                           parameters: nil
                                                                                 host: UPLOAD_ENDPOINT
                                                                          consumerKey: MUGMOVER_SMUGMUG_API_KEY_MACRO
                                                                       consumerSecret: MUGMOVER_SMUGMUG_SHARED_SECRET_MACRO
                                                                          accessToken: self.accessToken
                                                                          tokenSecret: self.tokenSecret
                                                                               scheme: UPLOAD_SCHEME
                                                                        requestMethod: @"POST"
                                                                         dataEncoding: TDOAuthContentTypeJsonObject
                                                                         headerValues: headerValues
                                                                      signatureMethod: TDOAuthSignatureMethodHmacSha1];
    if (!request)
    {
        DDLogError(@"Unable to create request object for upload");
        return nil;
    }
    request.HTTPBodyStream = inputStream;
    return request;
}

- (NSDictionary *) getAllFoldersForUser
{
    // https://api.smugmug.com/api/v2/folder/user/jayphillips!folders
    return nil;
}

- (NSDictionary *) getAllAlbumsForUser
{
    // #https://api/v2/user/cmac!albums?start=251&count=50
    return nil;
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
