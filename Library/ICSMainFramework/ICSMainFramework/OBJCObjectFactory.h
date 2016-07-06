//
//  ObjectInitializeHelper.h
//  ICSMainFramework
//
//  Created by LEI on 5/14/15.
//  Copyright (c) 2015 TouchingApp. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface OBJCObjectFactory : NSObject

/**
 Instantiates the specified class, which must
 descend (dircectly or indirectly) from NSObject.
 Uses the class's parameterless initializer.
 */
+ (id)create:(NSString *)className;

/**
 Instantiates the specified class, which must
 descend (dircectly or indirectly) from NSObject.
 Uses the specified initializer, passing it the
 argument provided via the `argument` parameter.
 */
+ (id)create:(NSString *)className
 initializer:(SEL)initializer
    argument:(id)argument;

@end
