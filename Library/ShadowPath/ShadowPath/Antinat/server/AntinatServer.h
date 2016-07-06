//
//  AntinatServer.h
//  Potatso
//
//  Created by LEI on 12/25/15.
//  Copyright © 2015 TouchingApp. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AntinatServer : NSObject
+ (AntinatServer *)sharedServer;
- (int)startWithConfig:(NSString *)config;
- (void)stop;
@end
