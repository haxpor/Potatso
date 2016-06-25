//
//  JSONUtils.h
//  Potatso
//
//  Created by LEI on 3/15/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (JSON)

- (NSDictionary * _Nullable)jsonDictionary;

- (NSArray * _Nullable)jsonArray;

@end


@interface NSDictionary (JSON)

- (NSData * _Nullable)jsonData;

- (NSString * _Nullable)jsonString;

@end

@interface NSArray (JSON)

- (NSData * _Nullable)jsonData;

- (NSString * _Nullable)jsonString;

@end