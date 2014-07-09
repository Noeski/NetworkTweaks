//
//  FBTweakClient.h
//  NetworkTweaks
//
//  Created by Noah Hilt on 7/6/14.
//  Copyright (c) 2014 Noah Hilt. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FBTweakClient;

@protocol FBTweakClientDelegate<NSObject>
@optional
- (void)clientConnectionAttemptSucceeded:(FBTweakClient *)client;
- (void)clientConnectionAttemptFailed:(FBTweakClient *)client;
- (void)clientConnectionTerminated:(FBTweakClient *)client;
- (void)client:(FBTweakClient *)client receivedMessage:(NSDictionary *)message;
@end

@interface FBTweakClient : NSObject<NSNetServiceDelegate>
@property (nonatomic, weak) id<FBTweakClientDelegate> delegate;

- (id)initWithNativeSocketHandle:(CFSocketNativeHandle)nativeSocketHandle;
- (id)initWithNetService:(NSNetService *)netService;

- (BOOL)connect;
- (void)close;
- (void)sendNetworkPacket:(NSDictionary *)packet;
@end