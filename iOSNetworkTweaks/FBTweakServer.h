//
//  FBTweakServer.h
//  iOSNetworkTweaks
//
//  Created by Noah Hilt on 7/6/14.
//  Copyright (c) 2014 ___FULLUSERNAME___. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FBTweakClient.h"

@interface FBTweakServer : NSObject<NSNetServiceDelegate, FBTweakClientDelegate>
- (BOOL)start;
- (void)stop;
@end
