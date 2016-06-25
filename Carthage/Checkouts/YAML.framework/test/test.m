//
//	test.m
//	YAML Serialization support by Mirek Rusin based on C library LibYAML by Kirill Simonov
//
//	Copyright 2010 Mirek Rusin, Released under MIT License
//

#import <Foundation/Foundation.h>
#import "YAMLSerialization.h"

int
test (int argc, char *argv[]) {
    int result = 0;

	NSLog(@"reading test file... ");
	NSData *data = [NSData dataWithContentsOfFile: @"yaml/basic.yaml"];
	NSInputStream *stream = [[[NSInputStream alloc] initWithFileAtPath: @"yaml/basic.yaml"] autorelease];
	NSLog(@"done.");

	NSTimeInterval before = [[NSDate date] timeIntervalSince1970];
	NSMutableArray *yaml = [YAMLSerialization objectsWithYAMLData: data options: kYAMLReadOptionStringScalars error: nil];
	NSLog(@"YAMLWithData took %f", ([[NSDate date] timeIntervalSince1970] - before));
	NSLog(@"%@", yaml);

    NSError *err = nil;
	NSTimeInterval before2 = [[NSDate date] timeIntervalSince1970];
	NSMutableArray *yaml2 = [YAMLSerialization objectsWithYAMLStream: stream options: kYAMLReadOptionStringScalars error: &err];
	NSLog(@"YAMLWithStream took %f", ([[NSDate date] timeIntervalSince1970] - before2));
	NSLog(@"%@", yaml2);

    err = nil;
	NSTimeInterval before3 = [[NSDate date] timeIntervalSince1970];
	NSOutputStream *outStream = [NSOutputStream outputStreamToMemory];
	[YAMLSerialization writeObject: yaml toYAMLStream: outStream options: kYAMLWriteOptionMultipleDocuments error: &err];
	if (err) {
		NSLog(@"Error: %@", err);
		return -1;
	}
	NSLog(@"writeYAML took %f", (float) ([[NSDate date] timeIntervalSince1970] - before3));
	NSLog(@"out stream %@", outStream);

	NSTimeInterval before4 = [[NSDate date] timeIntervalSince1970];
	NSData *outData = [YAMLSerialization YAMLDataWithObject: yaml2 options: kYAMLWriteOptionMultipleDocuments error: &err];
	if (!outData) {
		NSLog(@"Data is nil!");
		return -1;
	}
	NSLog(@"dataFromYAML took %f", ([[NSDate date] timeIntervalSince1970] - before4));
	NSLog(@"out data %@", outData);

    return result;
}

int
main (int argc, char *argv[]) {
    int result = 0;
    @autoreleasepool {
        result = test(argc, argv);
    }
	return result;
}