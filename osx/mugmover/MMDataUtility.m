//
//  MMDataUtility.m
//  mugmover
//
//  Created by Bob Fitterman on 4/1/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMDataUtility.h"

@implementation MMDataUtility

extern NSInteger const MMDefaultRetries;

/**
 This method ingests an NSData object that is expected to contain UTF-8 JSON-encoded Object.
 If it is successful, it returns the parsed data, which should always be an NSDictionary.
 If valid JSON is parsed and it is not a JSON Object (e.g., Array), nil will be returned.
 */
+ (NSDictionary *) parseJsonData: (NSData *) data
{
    if (data && ([data length] > 0))
    {
        NSError *jsonParsingError = nil;
        NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData: data
                                                                   options: 0
                                                                     error: &jsonParsingError];
        if (jsonParsingError)
        {
            NSString *formattedString = [[NSString alloc] initWithData: data
                                                              encoding: NSASCIIStringEncoding];
            NSInteger strLen = [formattedString length];
            if (strLen > 60)
            {
                formattedString = [NSString stringWithFormat: @"%@...", [formattedString substringToIndex: 60]];
            }
            DDLogError(@"ERROR         Malformed JSON %@ (%ld bytes)", formattedString, strLen);
        }
        else
        {
            if([dictionary isKindOfClass:[NSDictionary class]])
            {
                return dictionary;
            }
            else
            {
                DDLogInfo(@"ERROR         Valid JSON, but not an Object. Ignored.");
            }
        }
    }
    else
    {
        DDLogError(@"ERROR         No data received");
    }
    return nil;
}

/**
 * Takes in a string and encodes several characters that would otherwise not be encoded.
 * (Derived from http://stackoverflow.com/questions/8088473/url-encode-an-nsstring)
 */
+ (NSString *) percentEncodeAlmostEverything:(NSString *)inString
{
    NSMutableString *output = [NSMutableString string];
    const unsigned char *source = (const unsigned char *)[inString UTF8String];
    NSInteger sourceLen = strlen((const char *)source);
    for (int i = 0; i < sourceLen; ++i)
    {
        // While it is possible to expand the list of characters, it ends up being more
        // run-time testing. Including some basic characters leaves it readable and keeps
        // it getting too large.
        const unsigned char thisChar = source[i];
        if ((thisChar == ' ') ||
            (thisChar >= 'a' && thisChar <= 'z') ||
            (thisChar >= 'A' && thisChar <= 'Z') ||
            (thisChar >= '0' && thisChar <= '9'))
        {
            [output appendFormat:@"%c", thisChar];
        }
        else
        {
            [output appendFormat:@"%%%02X", thisChar];
        }
    }
    return output;
}

/**
 *
 * Makes a synchronous API call, with retries. If the call returns any HTTP status, it
 * will not be retried, because API calls use OAuth. OAuth calls will fail if retried
 * unless a new request is created, because the nonce will be detected by the server
 * as reused. The HTTP status will be returned and the +parsedData+ parameter will be
 * updated to point to a the returned JSON object. If the retries fail, the method
 * will return a value of zero. If the data cannot be parsed, the HTTP status wil be
 * valid, however the parsedData value will be set to nil. This can also happen if the
 * call (by design) does not return any data. Some servers may return no data if an
 * error status is being returned.
 *
 * Both arguments must be present, as the parsedServerData is a pointer to an
 * +(NSDictionary *)+ so it can be returned.
 
 */

+ (NSInteger) makeSyncJsonRequestWithRetries: (NSURLRequest *) request
                                  parsedData: (NSDictionary **) parsedServerData
{
    if ((!request) || (!parsedServerData))
    {
        return -1;
    }
    NSURLResponse *response;
    NSError *error;
    NSInteger retries = MMDefaultRetries;
    while (retries-- > 0)
    {
        NSData *serverData = [NSURLConnection sendSynchronousRequest: request
                                                   returningResponse: &response
                                                               error: &error];
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (error)
        {
            DDLogError(@"System error: %@", error);
            continue; // You can retry, unlikely to succeed
        }
        else
        {
            NSDictionary *newParsedData = [MMDataUtility parseJsonData: serverData];
            *parsedServerData = newParsedData;
            NSInteger httpStatus = [httpResponse statusCode];
            return httpStatus;
        }
    }
    parsedServerData = nil;
    return 0;
}

+ (NSError *) makeErrorForFilePath: (NSString *) filePath
                        codeString: (NSString *) codeString
{
    DDLogError(@"ERROR         Making error for filePath= %@ codeString=%@", filePath, codeString);
    NSString *recovery = NSLocalizedString(@"This may be due to corruption of the iPhoto Library. Supply the following value to Mugmover support.", nil);
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey:
                                   NSLocalizedString(@"Upload Preparation Failed", nil),
                               NSLocalizedFailureReasonErrorKey:
                                   NSLocalizedString(@"An error occurred while preparing the file for upload.", nil),
                               NSLocalizedRecoverySuggestionErrorKey:
                                   [NSString stringWithFormat: @"%@ (%@)", recovery, codeString],
                               @"MMFilePath": filePath};
    return [NSError errorWithDomain: [[NSBundle mainBundle] bundleIdentifier]
                               code: -60
                           userInfo: userInfo];
}

// DO NOT CHANGE THIS STRING AS STORED DATA RELIES ON IT NEVER CHANGING
#define RADIX "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-%"

/**
 * We convert a hex string into a Base64 representation using URL-safe characters 
 * of our choosing. We assume the caller has confirmed it only contains hex characters
 * and dashes. We squeeze out the dashes, but that's all the safety net we have.
 */
+ (NSString *) parseHexToOurBase64: (NSString *) hexString
{
    NSMutableString* result = [NSMutableString new];
    NSMutableString *workingString = [[hexString stringByReplacingOccurrencesOfString:@"-"
                                                                          withString:@""] mutableCopy];
    
    // If it's not up to a multiple of 3 (nibbles), make it so.
    NSInteger shortage = ([workingString length] % 3);
    if (shortage != 0)
    {
        while (shortage++ < 3)
        {
            [workingString appendString: @"0"];
        }
    }

    for (NSInteger idx = 0; idx + 3 <= workingString.length; idx += 3)
    {
        NSRange range = NSMakeRange(idx, 3);
        NSString* hexStr = [workingString substringWithRange: range];
        NSScanner* scanner = [NSScanner scannerWithString: hexStr];
        unsigned long long value;
        if ([scanner scanHexLongLong: &value])
        {
            unsigned long v1 = (value / 64);
            unsigned long v2 = value % 64;
            [result appendString:[@RADIX substringWithRange:NSMakeRange(v1, 1)]];
            [result appendString:[@RADIX substringWithRange:NSMakeRange(v2, 1)]];
        }
        else
        {
            NSLog(@"ERROR  Scanner detected non-hex characters");
            return nil;
        }
    }
    return (NSString *)result;
}
@end
