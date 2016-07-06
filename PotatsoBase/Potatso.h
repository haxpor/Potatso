//
//  PotatsoManager.h
//  Potatso
//
//  Created by LEI on 4/4/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * _Nonnull sharedGroupIdentifier;

@interface Potatso : NSObject
+ (NSURL * _Nonnull)sharedUrl;
+ (NSURL * _Nonnull)sharedDatabaseUrl;
+ (NSUserDefaults * _Nonnull)sharedUserDefaults;

+ (NSURL * _Nonnull)sharedGeneralConfUrl;
+ (NSURL * _Nonnull)sharedSocksConfUrl;
+ (NSURL * _Nonnull)sharedProxyConfUrl;
+ (NSURL * _Nonnull)sharedHttpProxyConfUrl;
+ (NSURL * _Nonnull)sharedLogUrl;
@end
