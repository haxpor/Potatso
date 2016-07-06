//
//  JSONUtils.m
//  Potatso
//
//  Created by LEI on 3/15/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

#import "JSONUtils.h"

@implementation NSString (JSON)

- (NSDictionary *)jsonDictionary {
    return [NSJSONSerialization JSONObjectWithData:[self dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:nil];
}

- (NSArray *)jsonArray {
    return [NSJSONSerialization JSONObjectWithData:[self dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:nil];
}

@end

@implementation NSDictionary (JSON)

- (NSData *)jsonData {
    return [NSJSONSerialization dataWithJSONObject:self options:0 error:nil];
}

- (NSString *)jsonString {
    return [[NSString alloc] initWithData:[self jsonData] encoding:NSUTF8StringEncoding];
}

@end

@implementation NSArray (JSON)

- (NSData *)jsonData {
    return [NSJSONSerialization dataWithJSONObject:self options:0 error:nil];
}

- (NSString *)jsonString {
    return [[NSString alloc] initWithData:[self jsonData] encoding:NSUTF8StringEncoding];
}

@end