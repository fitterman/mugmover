//
//  MMComplexTableCellView.h
//  mugmover
//
//  Created by Bob Fitterman on 4/4/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MMComplexTableCellView : NSTableCellView
{
@private
    IBOutlet NSTextField *firstTitleTextField;
    IBOutlet NSTextField *secondTextField;
    IBOutlet NSTextField *thirdTextField;
}

@property(assign) NSTextField *firstTitleTextField;
@property(assign) NSTextField *secondTextField;
@property(assign) NSTextField *thirdTextField;

@end