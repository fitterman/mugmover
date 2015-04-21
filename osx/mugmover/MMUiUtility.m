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
    [alert addButtonWithTitle: NSLocalizedString(@"OK", nil)];
    if (question)
    {
        [alert addButtonWithTitle: NSLocalizedString(@"Cancel", nil)];
        [alert setMessageText: question];
    }
    [alert setInformativeText: text];
    [alert setAlertStyle: warningOrErrorStyle];
    return ([alert runModal] == NSAlertFirstButtonReturn);
}

+ (void) alertWithError: (NSError *) error
                  style: (NSAlertStyle) warningOrErrorStyle
{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle: NSLocalizedString(@"OK", nil)];
    [alert setMessageText: error.localizedDescription];
    [alert setInformativeText: error.localizedRecoverySuggestion];
    [alert setAlertStyle: warningOrErrorStyle];
    [alert runModal];
}
@end
