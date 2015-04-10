//
//  MMCheckboxTableCellView.h
//  mugmover
//
//  Created by Bob Fitterman on 4/4/15.
//  Copyright (c) 2015 Dicentra LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class NSTableView;

@interface MMCheckboxTableCellView : NSTableCellView

@property (weak) IBOutlet       NSButton *       checkboxField;

@end