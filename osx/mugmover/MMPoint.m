//
//  MMPoint.m
//  mugmover
//
//  Created by Bob Fitterman on 11/13/14.
//  Copyright (c) 2014 Dicentra LLC. All rights reserved.
//

#import "MMPoint.h"

#define DEGREES_PER_RADIAN ((double)180.0 / 3.141592653589793238)


@implementation MMPoint

- (id)initWithX: (Float64) x
              y: (Float64) y
{
    self = [self init];
    if (self)
    {
        self.x = x;
        self.y = y;
    }
    return self;
}

// Rotate a point relative to another point, considered the origin. The
// straight-line distance and angle is determined, the angle is adjusted
// and the new location is updated to this object.
- (void) rotate: (Float64) degrees
     relativeTo: (MMPoint *) origin
{
    if ((self.x != origin.x) || (self.y != origin.y))
    {
        // Get the angle and straight-line distance of this point relative to the origin
        Float64 deltaX = self.x - origin.x;
        Float64 deltaY = self.y - origin.y;
        
        Float64 angle = atan(deltaY / deltaX) * DEGREES_PER_RADIAN;
        if (deltaX < 0)
        {
            angle += 180.0;
        }

        Float64 distance = sqrtl(pow(deltaX, 2.0) + pow(deltaY, 2.0));
        
        // See note above about why degrees is subtracted
        angle += degrees;                       // Rotated to the new angle
        angle = angle / DEGREES_PER_RADIAN;     // in radians
        Float64 newDeltaX = distance * cos(angle);
        Float64 newDeltaY = distance * sin(angle);
        self.x = origin.x + newDeltaX;
        self.y = origin.y + newDeltaY;
    }

}

- (void) scaleByXFactor: (Float64) xFactor
                yFactor: (Float64) yFactor
{
    _x *= xFactor;
    _y *= yFactor;
}

+ (id) midpointOf: (MMPoint *)p1 and: (MMPoint *)p2
{
    return [[MMPoint alloc] initWithX:(p1.x + p2.x) / 2.0 y: (p1.y + p2.y) / 2.0];
}

+ (Float64) distanceBetween:(MMPoint *)p1 and:(MMPoint *)p2
{
    return sqrt(pow((p1.x - p2.x), 2.0) + pow((p1.y - p2.y), 2.0));
}

- (NSString *) description
{
    if ((Float64) fabs(_x) < 1.0 || (Float64) fabs(_y) < 1.0)
    {
        return [NSString stringWithFormat:@"(%5.3f, %5.3f)", self.x, self.y];
    }
    else
    {
        return [NSString stringWithFormat:@"(%3.1f, %3.1f)", self.x, self.y];
    }
}

- (NSDictionary *) asDictionary
{
    return @{@"x": [NSNumber numberWithDouble: _x],
             @"y": [NSNumber numberWithDouble: _y]};
}
@end
