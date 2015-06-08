//
//  MMOauthSmugmug.m
//  mugmover
//
//  Created by Bob Fitterman on 3/24/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMDataUtility.h"
#import "MMFileUtility.h"
#import "MMOauthAbstract.h"
#import "MMOauthSmugmug.h"

#define SERVICE_SCHEME      @"https"
#define SERVICE_ENDPOINT    @"secure.smugmug.com"
#define UPLOAD_SCHEME       @"http"
#define UPLOAD_ENDPOINT     @"upload.smugmug.com"

@implementation MMOauthSmugmug

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

    // There's a special case in the API call for !authuser (and perhaps others). No slash
    // is needed as (apparently) the ! acts as a delimiter.
    NSString *apiCall;
    if ([api hasPrefix: @"!"])
    {
        apiCall = [NSString stringWithFormat: @"/api/v2%@", api];
    }
    else
    {
        apiCall = [NSString stringWithFormat: @"/api/v2/%@", api];
    }
    return [TDOAuth URLRequestForPath: apiCall
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
 +albumID+ is a string like "JX5d1" that is returned as the final element of the album URI
 */
- (NSURLRequest *) upload: (NSString *) filePath
                  albumId: (NSString *) albumId
           replacementFor: (NSString *) replacementFor
             withPriorMd5: (NSString *) priorMd5
                    title: (NSString *) title
                  caption: (NSString *) caption
                 keywords: (NSString *) keywords
                    error: (NSError  **) error
{
    if (!filePath)
    {
        return [self setErrorAndReturn: error filePath: @"" codeString: @"filePath"];
    }
    NSURL* fileUrl = [NSURL fileURLWithPath: filePath];
    if (!fileUrl)
    {
        return [self setErrorAndReturn: error filePath: filePath codeString: @"fileUrl"];
    }
    NSString *md5 = [MMFileUtility md5ForFileAtPath: filePath];
    if (!md5)
    {
        return [self setErrorAndReturn: error filePath: filePath codeString: @"MD5"];
    }
    // If we calculate the MD5 and this is a replacement, check whether it's already
    // on the service. If we're not supposed to reprocess a file already uploaded,
    // then the replacementFor will not be populated and we won't fall in this path.
    if (replacementFor && [md5 isEqualToString: priorMd5])
    {
        return nil; // Nothing to transfer
    }

    NSString* mimeType = [MMFileUtility mimeTypeForFileAtPath: filePath];
    if (!mimeType)
    {
        return [self setErrorAndReturn: error filePath: filePath codeString: @"mimeType"];
    }
    NSNumber *length = [MMFileUtility lengthForFileAtPath: filePath];
    if (!length)
    {
        return [self setErrorAndReturn: error filePath: filePath codeString: @"length"];
    }
    NSInputStream *inputStream = [NSInputStream inputStreamWithFileAtPath: filePath];
    if (!inputStream)
    {
        return [self setErrorAndReturn: error filePath: filePath codeString: @"inputStream"];
    }

    if (!albumId)
    {
        return [self setErrorAndReturn: error filePath: filePath codeString: @"albumId"];
    }
    NSString *albumUri = [NSString stringWithFormat: @"/api/v2/album/%@", albumId];
    NSMutableDictionary *headerValues = [[NSMutableDictionary alloc] init];
    if (!headerValues)
    {
        return [self setErrorAndReturn: error filePath: filePath codeString: @"headerValues"];
    }
    [headerValues setObject: @"application/json" forKey: @"Accept"];
    [headerValues setObject: [NSString stringWithFormat: @"%@", length] forKey: @"Content-Length"];
    [headerValues setObject: md5 forKey: @"Content-MD5"];
    [headerValues setObject: mimeType forKey: @"Content-Type"];
    [headerValues setObject: albumUri forKey: @"X-Smug-AlbumUri"];
    [headerValues setObject: [filePath lastPathComponent] forKey: @"X-Smug-FileName"];
    if (replacementFor)
    {
        [headerValues setObject: [NSString stringWithFormat: @"/api/v2/image/%@", replacementFor]
                         forKey: @"X-Smug-ImageUri"];
    }
    if (caption && ([caption length] > 0))
    {
        [headerValues setObject: [MMDataUtility percentEncodeAlmostEverything: caption] forKey: @"X-Smug-Caption"];
    }
    if (title && ([title length] > 0))
    {
        [headerValues setObject: [MMDataUtility percentEncodeAlmostEverything: title] forKey: @"X-Smug-Title"];
    }
    if (keywords && ([keywords length] > 0))
    {
        [headerValues setObject: [MMDataUtility percentEncodeAlmostEverything: keywords] forKey: @"X-Smug-Keywords"];
    }
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
        return [self setErrorAndReturn: error filePath: filePath codeString: @"requestValue"];
    }
    request.HTTPBodyStream = inputStream;
    return request;
}

#pragma mark Private Methods

/**
 * Method to build an error object. It (oddly) returns nil so the caller can just say
 * "return setErrorAndReturn:codeString". This is handy because often the caller wants
 * to set an error and return a nil value. If not, just call it and ignoring its return
 * value.
 */
- (id) setErrorAndReturn: (NSError **) error
                filePath: (NSString *) filePath
              codeString: (NSString *) codeString
{
    *error = [MMDataUtility makeErrorForFilePath: filePath codeString: codeString];
    return nil;
}

- (void) doOauthDance: (NSDictionary *)params;
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
                                           dataEncoding: TDOAuthContentTypeJsonObject
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

- (NSString *) extractErrorResponseData: (NSDictionary *) parsedServerResponse
{
    NSMutableArray *errors = [[NSMutableArray alloc] initWithCapacity: 100];
    if (!parsedServerResponse)
    {
        return @"no error details received";
    }
    NSDictionary *options = [parsedServerResponse objectForKey: @"Options"];
    NSDictionary *parameters = [options objectForKey: @"Parameters"];
    NSArray *fields = [parameters objectForKey: @"PATCH"];
    if (!fields)
    {
        fields = [parameters objectForKey: @"POST"];
    }
    if (!fields)
    {
        fields = [parameters objectForKey: @"GET"];
    }
    for (NSDictionary *field in fields)
    {
        NSArray *problems = [field objectForKey: @"Problems"];
        if (problems)
        {
            for (NSString *problem in problems)
            {
                NSString *oneError = [NSString stringWithFormat: @"Error \"%@\" on field %@ (value=%@)",
                                                                   problem,
                                                                   [field objectForKey: @"Name"],
                                                                   [field objectForKey: @"Value"]];
                [errors addObject: oneError];
            }
        }
    }
    if ([errors count] == 0)
    {
        return [super extractErrorResponseData: parsedServerResponse];
    }
    else
    {
        return [errors componentsJoinedByString: @"; %"];
    }
}


@end
