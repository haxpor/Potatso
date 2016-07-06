//
//  YAMLUnitTests.m
//  YAMLUnitTests
//
//  Created by Carl Brown on 7/31/11.
//  Copyright 2011 PDAgent, LLC. Released under MIT License.
//

#import "YAMLUnitTests.h"
#import "YAMLSerialization.h"

@implementation YAMLUnitTests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)testReadData
{
    NSString *fileName = [[NSBundle bundleForClass:[self class]] pathForResource:@"basic" ofType:@"yaml"];
	NSData *data = [NSData dataWithContentsOfFile:fileName];
    NSTimeInterval before = [[NSDate date] timeIntervalSince1970];
	NSMutableArray *yaml = [YAMLSerialization YAMLWithData: data options: kYAMLReadOptionStringScalars error: nil];
	NSLog(@"YAMLWithData took %f", ([[NSDate date] timeIntervalSince1970] - before));
	NSLog(@"%@", yaml);
    XCTAssertEqual((int) 10, (int) [yaml count], @"Wrong number of expected objects");

}

- (void)testReadStream
{
    NSString *fileName = [[NSBundle bundleForClass:[self class]] pathForResource:@"basic" ofType:@"yaml"];
    NSInputStream *stream = [[NSInputStream alloc] initWithFileAtPath: fileName];
    NSError *err = nil;
	NSTimeInterval before2 = [[NSDate date] timeIntervalSince1970]; 
	NSMutableArray *yaml2 = [YAMLSerialization YAMLWithStream: stream options: kYAMLReadOptionStringScalars error: &err];
	NSLog(@"YAMLWithStream took %f", ([[NSDate date] timeIntervalSince1970] - before2));
	NSLog(@"%@", yaml2);
    XCTAssertEqual((int) 10, (int) [yaml2 count], @"Wrong number of expected objects");
    
}

@end
