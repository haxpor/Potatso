//
//  spec12examples.m
//  Load all examples from http://www.yaml.org/spec/1.2/spec.html
//
//  Copyright 2010 Mirek Rusin, Released under MIT License
//

#import <Foundation/Foundation.h>
#import "YAMLSerialization.h"

int main() {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  NSString *prefix = @"spec12-example";
  for (NSString *path in [[NSFileManager defaultManager] contentsOfDirectoryAtPath: @"yaml" error: nil]) {
    if ([path compare: prefix options: NSCaseInsensitiveSearch range: NSMakeRange(0, prefix.length)] == NSOrderedSame) {
      
      NSInputStream *stream = [[NSInputStream alloc] initWithFileAtPath: [@"yaml" stringByAppendingPathComponent: path]];
      NSMutableArray *yaml = [YAMLSerialization YAMLWithStream: stream 
                                                       options: kYAMLReadOptionStringScalars
                                                         error: nil];
      
      // NSStringFromClass([[yaml objectAtIndex: 0] class]).UTF8String
      printf("Found %i docs in %s\n", (int)yaml.count, path.UTF8String);
    }
  }
  
  [pool drain];
  
  return 0;
}