//
//  MMComplexTableCellView.h
//  mugmover
//
//  Created by Bob Fitterman on 4/4/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class NSTableView;

@interface MMComplexTableCellView : NSTableCellView

@property (weak) IBOutlet       NSTextField *       firstTitleTextField;
@property (weak) IBOutlet       NSTextField *       secondTextField;
@property (weak) IBOutlet       NSTextField *       thirdTextField;

@end