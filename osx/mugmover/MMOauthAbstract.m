//
//  MMOauthAbstract
//  mugmover
//
//  Created by Bob Fitterman on 3/25/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMOauthAbstract.h"
#import <CommonCrypto/CommonDigest.h>

@implementation MMOauthAbstract
@synthesize accessToken = _accessToken;

extern const NSInteger MMDefaultRetries;

#pragma mark Class (utility) Methods
/**
 * From http://stackoverflow.com/questions/1363813/how-can-you-read-a-files-mime-type-in-objective-c
 */
+ (NSString *) mimeTypeForFileAtPath: (NSString *) path
{
    if (![[NSFileManager defaultManager] fileExistsAtPath: path]) {
        return nil;
    }
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)[path pathExtension], NULL);
    CFStringRef mimeType = UTTypeCopyPreferredTagWithClass (UTI, kUTTagClassMIMEType);
    CFRelease(UTI);
    if (!mimeType) {
        return @"application/octet-stream";
    }
    return (NSString *)CFBridgingRelease(mimeType);
}
/*
 * From http://stackoverflow.com/questions/10988369/is-there-a-md5-library-that-doesnt-require-the-whole-input-at-the-same-time
 */
+ (NSString *) md5ForFileAtPath: (NSString *) path
{
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath: path];
    if (!handle)
    {
        return nil;
    }
    
    CC_MD5_CTX md5;
    CC_MD5_Init(&md5);
    CC_LONG const chunkSize = 32000;
    
    while (YES)
    {
        @autoreleasepool
        {
            NSData *fileData = [handle readDataOfLength: chunkSize ];
            CC_MD5_Update(&md5, [fileData bytes], (CC_LONG)[fileData length]);
            if ([fileData length] == 0)
            {
                break;
            }
        }
    }
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(digest, &md5);

    NSString* s = [NSString stringWithFormat: @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                   digest[0], digest[1],
                   digest[2], digest[3],
                   digest[4], digest[5],
                   digest[6], digest[7],
                   digest[8], digest[9],
                   digest[10], digest[11],
                   digest[12], digest[13],
                   digest[14], digest[15]];
    return s;
}

+ (NSNumber *) lengthForFileAtPath: (NSString *) path
{
    NSError *error;
    NSDictionary *dict = [[NSFileManager defaultManager] attributesOfItemAtPath: path error: &error];
    if (error)
    {
        return nil;
    }
    return [dict objectForKey:NSFileSize];
}

/**
 This method ingests an NSData object that is expected to contain UTF-8 JSON-encoded data.
 If it is successful, it returns the parsed data, which should always be an NSDictionary.
 No attempt is made to validate that assumption in this routine. If an error occurs, it is
 logged and nil is returned.
 */
+ (NSDictionary *) parseJsonData: (NSData *)data
{
    if ([data length] > 0)
    {
        NSError *jsonParsingError = nil;
        NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData: data
                                                                   options: 0
                                                                     error: &jsonParsingError];
        if (jsonParsingError)
        {
            DDLogError(@"ERROR      malformed JSON");
            DDLogError(@"%@", [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding]);
        }
        else
        {
            return dictionary;
        }
    }
    else
    {
        DDLogError(@"ERROR      No data received");
    }
    return nil;
}

#pragma mark Public Methods

- (id) initAndStartAuthorization: (ProgressBlockType) progressBlock
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
    if (_accessToken && _tokenSecret && ([_accessToken length] > 0) && ([_tokenSecret length] > 0))
    {
        [self updateState: 1.0 asText: @"Successfully initialized"];    // We go right to the initialized state
        return self;
    }
    [self close];
    return nil;
}

- (NSURLRequest *)apiRequest: (NSString *)api
                  parameters: (NSDictionary *)parameters
                        verb: (NSString *)verb
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
                                 userInfo:nil];
}

- (void) close
{
    _accessToken = nil;
    _initializationStatusString = nil;
    _progressBlock = nil;
    _tokenSecret = nil;
}

- (void) processUrlRequest: (NSURLRequest *) request
                     queue: (NSOperationQueue *) queue
         remainingAttempts: (NSInteger) remainingAttempts
         completionHandler: (ServiceResponseHandler) serviceResponseHandler;
{
    if (remainingAttempts <= 0)
    {
        DDLogError(@"ERROR      maxRetriesExceeded for %@", request);
        return;
    }
    [NSURLConnection sendAsynchronousRequest: request
                                       queue: queue
                           completionHandler: ^(NSURLResponse *response,
                                                NSData *serverData,
                                                NSError *connectionError)
     {
         if (connectionError)
         {
             DDLogError(@"ERROR      connectionError=%@", connectionError);
             // TODO BE SURE YOU CHECK FOR AN AUTH ERROR AND DO NO RETRY ON AN AUTH ERROR
             if (remainingAttempts <= 0)
             {
                 DDLogError(@"ERROR      maxRetriesExceeded for %@", request);
             }
             else
             {
                 DDLogInfo(@"RETRYING   remainingAttempts=%ld", (long)remainingAttempts);
                 [self processUrlRequest: request
                                   queue: queue
                       remainingAttempts: remainingAttempts - 1
                       completionHandler: serviceResponseHandler];
                 return;
             }
         }
         else
         {
             NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
             if ([httpResponse statusCode] != 200)
             {
                 DDLogError(@"ERROR      httpError=%ld", (long)[httpResponse statusCode]);
                 if ([serverData length] > 0)
                 {
                     NSString *s = [[NSString alloc] initWithData: serverData encoding: NSUTF8StringEncoding];
                     DDLogError(@"response=%@", s);
                 }
             }
             else
             {
                 NSDictionary *parsedJsonData = [MMOauthAbstract parseJsonData: serverData];
                 if (parsedJsonData)
                 {
                     serviceResponseHandler(parsedJsonData);
                 }
             }
         }
     }];
}

#pragma mark Private Methods

- (void)doOauthDance: (NSDictionary *)params;
{
    [NSException raise:NSInternalInconsistencyException
                format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
}

#pragma mark "Protected" Methods

/**
 This method divides a complete URL at the "?" character, then parses the parameters present
 and returns a dictionary of key-value pairs.
 */
- (NSMutableDictionary *) extractQueryParams: (NSString *) urlAsString
{
    NSArray *pieces = [urlAsString componentsSeparatedByString:@"?"];
    
    if ([pieces count] != 2)
    {
        return nil; // signals a problem
    }
    return [self splitQueryParams: [pieces objectAtIndex: 1]];
}

/**
 This accepts the callback to the mugmover: protocol scheme, for example "mugmover://smugmug?..."
 */
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

/**
 This method splits a series of values like "foo=bar&baz=bonk" into a dictionary of key-value pairs.
 */
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
    // If it's failing early on, be sure it's not a problem with a missing configuration
    if ((state == -1.0) && (_initializationStatusValue == (float)0.2))
    {
        DDLogError(@"Make sure secrets.xcconfig defines the API key and secret.");
    }
    _initializationStatusValue = state;
    _initializationStatusString = text;
    if (_progressBlock)
    {
        _progressBlock(state, text);
    }
}

@end
