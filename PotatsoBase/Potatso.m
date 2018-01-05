//
//  PotatsoManager.m
//  Potatso
//
//  Created by LEI on 4/4/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

#import "Potatso.h"

static NSString* groupIdentifier = nil;

@implementation Potatso

+ (NSString *) sharedGroupIdentifier {
    // improved version for fix of issue 13
    // if groupIdentifier is not set yet, then we grab value from key inside Info.plist of Potatso target
    // cleaner way to get this than fixed code as before
    if (groupIdentifier == nil) {
        NSDictionary<NSString*, id> *infoDict = [[NSBundle mainBundle] infoDictionary];
        NSAssert(infoDict != nil, @"Dictionary get from NSBundle should not be null");
        if (infoDict != nil) {
            NSDictionary<NSString*, id> *potatsoInternalDict = infoDict[@"PotatsoInternal"];
            NSAssert(potatsoInternalDict != nil, @"We should have PotatsoInternal inside Info.plist of Potatso main target. It needs to be existing.");
            if (potatsoInternalDict != nil) {
                NSString* pGroupIdentifier = potatsoInternalDict[@"GroupIdentifier"];
                NSAssert(pGroupIdentifier != nil, @"Group identifier needs to have value");
                groupIdentifier = [NSString stringWithString: pGroupIdentifier];
            }
        }
    }

    return groupIdentifier;
}

+ (NSURL *)sharedUrl {
    return [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:[self sharedGroupIdentifier]];
}

+ (NSURL *)sharedDatabaseUrl {
    return [[self sharedUrl] URLByAppendingPathComponent:@"potatso.realm"];
}

+ (NSUserDefaults *)sharedUserDefaults {
    return [[NSUserDefaults alloc] initWithSuiteName:[self sharedGroupIdentifier]];
}

+ (NSURL * _Nonnull)sharedGeneralConfUrl {
    return [[Potatso sharedUrl] URLByAppendingPathComponent:@"general.xxx"];
}

+ (NSURL *)sharedSocksConfUrl {
    return [[Potatso sharedUrl] URLByAppendingPathComponent:@"socks.xxx"];
}

+ (NSURL *)sharedProxyConfUrl {
    return [[Potatso sharedUrl] URLByAppendingPathComponent:@"proxy.xxx"];
}

+ (NSURL *)sharedHttpProxyConfUrl {
    return [[Potatso sharedUrl] URLByAppendingPathComponent:@"http.xxx"];
}

+ (NSURL * _Nonnull)sharedLogUrl {
    return [[Potatso sharedUrl] URLByAppendingPathComponent:@"tunnel.log"];
}

@end
