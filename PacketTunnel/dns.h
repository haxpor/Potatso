//
//  dns.h
//  Potatso
//
//  Created by LEI on 11/11/15.
//  Copyright © 2015 TouchingApp. All rights reserved.
//

#ifndef dns_h
#define dns_h

#include <stdio.h>
#include <Foundation/Foundation.h>

@interface DNSConfig : NSObject

+ (NSArray *) getSystemDnsServers;
@end

#endif /* dns_h */
