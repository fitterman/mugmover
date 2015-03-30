//
//  MMOauthAbstract
//  mugmover
//
//  Created by Bob Fitterman on 3/25/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMOauthAbstract.h"

@implementation MMOauthAbstract

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
    return self;
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
                 if ([serverData length] > 0)
                 {
                     NSError *jsonParsingError = nil;
                     NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData: serverData
                                                                                options: 0
                                                                                  error: &jsonParsingError];
                     if (jsonParsingError)
                     {
                         DDLogError(@"ERROR      malformed JSON");
                         DDLogError(@"%@", [[NSString alloc] initWithData: serverData encoding: NSUTF8StringEncoding]);
                     }
                     else
                     {
                         serviceResponseHandler(dictionary);
                     }
                 }
                 else
                 {
                     DDLogError(@"ERROR      No data received");
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
