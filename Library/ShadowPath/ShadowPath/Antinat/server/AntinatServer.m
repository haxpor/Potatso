//
//  AntinatServer.m
//  Potatso
//
//  Created by LEI on 12/25/15.
//  Copyright © 2015 TouchingApp. All rights reserved.
//

#import "AntinatServer.h"
#import "an_main.h"
#import "an_serv.h"

@implementation AntinatServer

+ (AntinatServer *)sharedServer {
    static dispatch_once_t onceToken;
    static AntinatServer *server;
    dispatch_once(&onceToken, ^{
        server = [AntinatServer new];
    });
    return server;
}

- (instancetype)init {
    self = [super init];
    if (self){
        conn_dict = [NSMutableDictionary dictionary];
    }
    return self;
}

- (int)startWithConfig:(NSString *)config {
    int fd = an_setup([config UTF8String], (int)config.length);
    [NSThread detachNewThreadSelector:@selector(start) toTarget:self withObject:nil];
    return fd;
}

- (void)start {
    an_main();
}

- (void)stop {
    closeup(0);
}

@end
