//
//  NSError+Helper.h
//  Potatso
//
//  Created by LEI on 3/23/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSError (Helper)

+ (NSError *)errorWithCode: (NSInteger)code description: (NSString *)description;

@end
