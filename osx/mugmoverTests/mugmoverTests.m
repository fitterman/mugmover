//
//  mugmoverTests.m
//  mugmoverTests
//
//  Created by Bob Fitterman on 11/13/14.
//  Copyright (c) 2014 Dicentra LLC. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MMPoint.h"
#import "MMFace.h"

@interface mugmoverTests : XCTestCase

- (void) testMidpointCalculation;
- (void) testDistanceCalculationDiagonally;
- (void) testDistanceCalculationHorizontally;
- (void) testDistanceCalculationVertically;

@end

@implementation mugmoverTests

- (void) setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void) tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void) testMidpointCalculation
{
    MMPoint *p1 = [[MMPoint alloc] initWithX: 1.5 y: 1.5];
    MMPoint *p2 = [[MMPoint alloc] initWithX: -1.0 y: 1.0];
    MMPoint *midpoint = [MMPoint midpointOf: p1 and: p2];
    XCTAssertEqualWithAccuracy(midpoint.x, .25, 0.01);
    XCTAssertEqualWithAccuracy(midpoint.y, 1.25, 0.01);
}

- (void) testDistanceCalculationDiagonally;
{
    MMPoint *p1 = [[MMPoint alloc] initWithX: 1.0 y: 1.0];
    MMPoint *p2 = [[MMPoint alloc] initWithX: 4.0 y: 5.0];
    XCTAssertEqualWithAccuracy([MMPoint distanceBetween: p1 and: p2], 5.0, 0.01);
}

- (void) testDistanceCalculationHorizontally;
{
    MMPoint *p1 = [[MMPoint alloc] initWithX: -0.5 y: 1.5];
    MMPoint *p2 = [[MMPoint alloc] initWithX: 1.5 y: 1.5];
    XCTAssertEqualWithAccuracy([MMPoint distanceBetween: p1 and: p2], 2.0, 0.01);
}

- (void) testDistanceCalculationVertically;
{
    MMPoint *p1 = [[MMPoint alloc] initWithX: 1.5 y: 1.5];
    MMPoint *p2 = [[MMPoint alloc] initWithX: 1.5 y: 1.0];
    XCTAssertEqualWithAccuracy([MMPoint distanceBetween: p1 and: p2], 0.5, 0.01);
    
}

- (void) testFaceCreation
{
    MMFace *topRightSquare = [[MMFace alloc] initFromIphotoWithTopLeft: [[MMPoint alloc] initWithX: 0.808162715123663 y: 0.731601784929713]
                                                           bottomRight: [[MMPoint alloc] initWithX: 0.990247876728963 y: 0.996058805356458]
                                                           masterWidth: 732
                                                          masterHeight: 504];

    XCTAssertEqualWithAccuracy(topRightSquare.faceCenter.x, 658.218, 0.001, "faceCenter.x failed");
    XCTAssertEqualWithAccuracy(topRightSquare.faceCenter.y, 435.370, 0.001, "faceCenter.y failed");
    
    XCTAssertEqualWithAccuracy(topRightSquare.faceWidth, 133.286, 0.001, "width failed");
    XCTAssertEqualWithAccuracy(topRightSquare.faceHeight, 133.286, 0.001, "height failed");
    
    XCTAssertEqualWithAccuracy(topRightSquare.radius, 344.987, 0.001, "radius failed");
    XCTAssertEqualWithAccuracy(topRightSquare.originalAngle, 32.108, 0.001, "angle failed");
}

- (void) testRotateToPixels;
{
    MMFace *topRightSquare = [[MMFace alloc] initFromIphotoWithTopLeft: [[MMPoint alloc] initWithX: 0.808162715123663 y: 0.731601784929713]
                                                              topRight: [[MMPoint alloc] initWithX: 0.990247876728963 y: 0.731601784929713]
                                                           bottomRight: [[MMPoint alloc] initWithX: 0.990247876728963 y: 0.996058805356458]
                                                            bottomLeft: [[MMPoint alloc] initWithX: 0.808162715123663 y: 0.996058805356458]
                                                           masterWidth: 732
                                                          masterHeight: 504];
    
    MMPoint *rotatedCenter = [topRightSquare rotateToPixels: 0.0];
    XCTAssertEqualWithAccuracy(rotatedCenter.x, 658.218, 0.001, "x with rotation 0.0 failed");
    XCTAssertEqualWithAccuracy(rotatedCenter.y, 435.370, 0.001, "y with rotation 0.0 failed");
    
    rotatedCenter = [topRightSquare rotateToPixels: 32.108];
    XCTAssertEqualWithAccuracy(rotatedCenter.x, 710.987, 0.001, "x with rotation 32.108 failed");
    XCTAssertEqualWithAccuracy(rotatedCenter.y, 252.004, 0.001, "y with rotation 32.108 failed");

}



@end
