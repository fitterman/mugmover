//
//  MMUIUtility.m
//  mugmover
//
//  Created by Bob Fitterman on 4/7/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import "MMUIUtility.h"
// #import <Foundation/Foundation.h>

@implementation MMUiUtility


+ (BOOL) alertWithText: (NSString *) text
          withQuestion: (NSString *) question
                 style: (NSAlertStyle) warningOrErrorStyle
{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle: @"OK"];
    if (question)
    {
        [alert addButtonWithTitle: @"Cancel"];
        [alert setMessageText: question];
    }
    [alert setInformativeText: text];
    [alert setAlertStyle: warningOrErrorStyle];
    return ([alert runModal] == NSAlertFirstButtonReturn);
}
@end
