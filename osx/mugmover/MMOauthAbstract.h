//
//  MMOauthAbstract.h
//  mugmover
//
//  Created by Bob Fitterman on 3/25/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <TDOAuth.h>

@interface MMOauthAbstract : TDOAuth

typedef void (^ProgressBlockType)(Float32, NSString *);
typedef void (^ServiceResponseHandler)(NSDictionary *serviceResponseDictionary);

+ (NSNumber *) lengthForFileAtPath: (NSString *) path;

+ (NSString *) md5ForFileAtPath: (NSString *) path;

+ (NSString *) mimeTypeForFileAtPath: (NSString *) path;

- (id) initAndStartAuthorization: (ProgressBlockType) progressBlock;

- (id) initWithStoredToken: (NSString *) token
                    secret: (NSString *) secret;

- (NSURLRequest *)apiRequest: (NSString *) api
                  parameters: (NSDictionary *) parameters
                        verb: (NSString *) verb;

- (void) close;

- (void) processUrlRequest: (NSURLRequest *) request
                     queue: (NSOperationQueue *) queue
         remainingAttempts: (NSInteger) remainingAttempts
         completionHandler: (ServiceResponseHandler) serviceResponseHandler;

@end

@interface MMOauthAbstract()

@property (strong, readonly)    NSString *          accessToken;
@property (assign, readonly)    float               initializationStatusValue;
@property (strong, readonly)    NSString *          initializationStatusString;
@property (strong, readonly)    NSString *          tokenSecret;
@property (strong, readonly)    ProgressBlockType   progressBlock;

@end

@interface MMOauthAbstract(protected)
// They aren't really protected, but as a concept it's nice.
// I could put these in a separate file to segregate them.
- (NSMutableDictionary *) extractQueryParams: (NSString *) urlAsString;

- (void) handleIncomingURL: (NSAppleEventDescriptor *) event
            withReplyEvent: (NSAppleEventDescriptor *) replyEvent;

- (NSMutableDictionary *) splitQueryParams: (NSString *) inString;

- (void) updateState: (float) state
              asText: (NSString *) text;

@end

