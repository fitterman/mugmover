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
        [alert setInformativeText: question];
    }
    [alert setMessageText: text];
    [alert setAlertStyle: warningOrErrorStyle];
    return ([alert runModal] == NSAlertFirstButtonReturn);
}

+ (void) alertWithError: (NSError *) error
                  style: (NSAlertStyle) warningOrErrorStyle
{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle: NSLocalizedString(@"OK", nil)];
    [alert setMessageText: error.localizedDescription];
    NSString *extra = @"";
    if (error.localizedRecoverySuggestion)
    {
        extra = [extra stringByAppendingString: error.localizedRecoverySuggestion];
    }
    NSString *filePath = [error.userInfo objectForKey :@"MMFilePath"];
    if (filePath && [filePath length] > 0)
    {
        if ([extra length] > 0)
        {
            extra = [extra stringByAppendingString: @"\n"];
        }
        [extra stringByAppendingString: filePath];
    }
    if ([extra length] > 0)
    {
        [alert setInformativeText: extra];
    }

    [alert setAlertStyle: warningOrErrorStyle];
    [alert runModal];
}

+ (NSImage *) iconImage: (NSString *) name
                 ofType: (NSString *) ofType
{
    NSString *imageName = [[NSBundle mainBundle] pathForResource: name ofType: ofType];
    return [[NSImage alloc] initWithContentsOfFile: imageName];
}

@end
