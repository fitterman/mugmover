//
//  MMUIUtility.h
//  mugmover
//
//  Created by Bob Fitterman on 4/7/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MMUiUtility : NSObject

+ (void) alertWithError: (NSError *) error
                  style: (NSAlertStyle) warningOrErrorStyle;

+ (BOOL) alertWithText: (NSString *) text
          withQuestion: (NSString *) question
                 style: (NSAlertStyle) warningOrErrorStyle;

+ (NSImage *) iconImage: (NSString *) name
                 ofType: (NSString *) ofType;

@end
