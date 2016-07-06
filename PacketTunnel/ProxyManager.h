//
//  ProxyManager.h
//  Potatso
//
//  Created by LEI on 2/23/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^SocksProxyCompletion)(int port, NSError *error);
typedef void(^HttpProxyCompletion)(int port, NSError *error);
typedef void(^ShadowsocksProxyCompletion)(int port, NSError *error);

extern int sock_port (int fd);

@interface ProxyManager : NSObject

+ (ProxyManager *)sharedManager;
@property (nonatomic, readonly) BOOL socksProxyRunning;
@property (nonatomic, readonly) int socksProxyPort;
@property (nonatomic, readonly) BOOL httpProxyRunning;
@property (nonatomic, readonly) int httpProxyPort;
@property (nonatomic, readonly) BOOL shadowsocksProxyRunning;
@property (nonatomic, readonly) int shadowsocksProxyPort;
- (void)startSocksProxy: (SocksProxyCompletion)completion;
- (void)stopSocksProxy;
- (void)startHttpProxy: (HttpProxyCompletion)completion;
- (void)stopHttpProxy;
- (void)startShadowsocks: (ShadowsocksProxyCompletion)completion;
- (void)stopShadowsocks;
@end
