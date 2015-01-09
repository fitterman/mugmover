//
//  MMPoint.h
//  mugmover
//
//  Created by Bob Fitterman on 11/13/14.
//  Copyright (c) 2014 Dicentra LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MMPoint : NSObject
@property (assign) Float64 x;
@property (assign) Float64 y;

- (id) initWithX: (Float64) x
               y: (Float64) y;

- (NSDictionary *) asDictionary;

- (void) rotate: (Float64) degrees
     relativeTo: (MMPoint *) origin;

- (void) scaleByXFactor: (Float64) xFactor
                yFactor: (Float64) yFactor;

+ (id) midpointOf: (MMPoint *) p1
              and: (MMPoint *) p2;

+ (Float64) distanceBetween: (MMPoint *) p1
                        and: (MMPoint *) p2;

@end
