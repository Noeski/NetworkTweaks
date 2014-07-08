//
//  FBTweakServer.m
//  iOSNetworkTweaks
//
//  Created by Noah Hilt on 7/6/14.
//  Copyright (c) 2014 ___FULLUSERNAME___. All rights reserved.
//

#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <CFNetwork/CFSocketStream.h>

#import "FBTweakServer.h"
#import "FBTweakStore.h"
#import "FBTweakCategory.h"
#import "FBTweakCollection.h"
#import "FBTweak.h"

@interface FBTweakServer() {
    CFSocketRef _listeningSocket;
}

@property (nonatomic, assign) NSInteger port;
@property (nonatomic, strong) NSNetService *netService;
@property (nonatomic, strong) NSMutableArray *clients;

- (BOOL)createServer;
- (void)terminateServer;

- (BOOL)publishService;
- (void)unpublishService;
@end

@implementation FBTweakServer

- (id)init {
    if(self = [super init]) {
        _clients = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (void)dealloc {
    [self stop];
}

- (BOOL)start {
    if(![self createServer]) {
        return NO;
    }
    
    if(![self publishService]) {
        [self terminateServer];
        return NO;
    }
    
    return YES;
}

- (void)stop {
    [self terminateServer];
    [self unpublishService];
}

- (void)refreshData:(FBTweakClient *)client {
    FBTweakStore *tweakStore = [FBTweakStore sharedInstance];
    
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    NSMutableArray *categoryArray = [NSMutableArray array];
    
    for(FBTweakCategory *tweakCategory in tweakStore.tweakCategories) {
        NSMutableDictionary *categoryDictionary = [NSMutableDictionary dictionary];
        categoryDictionary[@"name"] = tweakCategory.name;

        NSMutableArray *collectionArray = [NSMutableArray array];
        
        for(FBTweakCollection *tweakCollection in tweakCategory.tweakCollections) {
            NSMutableDictionary *collectionDictionary = [NSMutableDictionary dictionary];
            collectionDictionary[@"name"] = tweakCollection.name;
            
            NSMutableArray *tweakArray = [NSMutableArray array];
            
            for(FBTweak *tweak in tweakCollection.tweaks) {
                NSMutableDictionary *tweakDictionary = [NSMutableDictionary dictionary];
                tweakDictionary[@"name"] = tweak.name;
                tweakDictionary[@"identifier"] = tweak.identifier;

                NSString *tweakType = @"None";
                
                FBTweakValue value = tweak.currentValue ? tweak.currentValue : tweak.defaultValue;
                FBTweakValue minimumValue = tweak.minimumValue;
                FBTweakValue maximumValue = tweak.maximumValue;
                FBTweakValue stepValue = tweak.stepValue;
                FBTweakValue precisionValue = tweak.precisionValue;

                if([value isKindOfClass:[NSString class]]) {
                    tweakType = @"String";
                }
                else if([value isKindOfClass:[NSNumber class]]) {
                    // In the 64-bit runtime, BOOL is a real boolean.
                    // NSNumber doesn't always agree; compare both.
                    if (strcmp([value objCType], @encode(char)) == 0 ||
                        strcmp([value objCType], @encode(_Bool)) == 0) {
                        tweakType = @"Boolean";
                    }
                    else if(strcmp([value objCType], @encode(NSInteger)) == 0 ||
                            strcmp([value objCType], @encode(NSUInteger)) == 0) {
                       tweakType = @"Integer";
                    }
                    else {
                        tweakType = @"Real";
                    }
                }
                else if([tweak isAction]) {
                    tweakType = @"Action";
                    value = nil;
                }
                
                tweakDictionary[@"type"] = tweakType;
                
                if(value) {
                    tweakDictionary[@"value"] = value;
                }
                
                if(minimumValue) {
                    tweakDictionary[@"minimumValue"] = minimumValue;
                }
                
                if(maximumValue) {
                    tweakDictionary[@"maximumValue"] = maximumValue;
                }
                
                if(stepValue) {
                    tweakDictionary[@"stepValue"] = stepValue;
                }
                
                if(precisionValue) {
                    tweakDictionary[@"precisionValue"] = precisionValue;
                }
                
                [tweakArray addObject:tweakDictionary];
            }
            
            collectionDictionary[@"tweaks"] = tweakArray;
            [collectionArray addObject:collectionDictionary];
        }
        
        categoryDictionary[@"collections"] = collectionArray;
        [categoryArray addObject:categoryDictionary];
    }
    
    dictionary[@"categories"] = categoryArray;
    
    [client sendNetworkPacket:dictionary];
}

#pragma mark Callbacks

- (void)handleNewNativeSocket:(CFSocketNativeHandle)nativeSocketHandle {
    FBTweakClient *client = [[FBTweakClient alloc] initWithNativeSocketHandle:nativeSocketHandle];
    
    // In case of errors, close native socket handle
    if(client == nil) {
        close(nativeSocketHandle);
        return;
    }
    
    // finish connecting
    if(![client connect]) {
        [client close];
        client = nil;
        return;
    }
    
    client.delegate = self;
    [self.clients addObject:client];
}


static void serverAcceptCallback(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
    FBTweakServer *server = (__bridge FBTweakServer*)info;
    
    // We can only process "connection accepted" calls here
    if ( type != kCFSocketAcceptCallBack ) {
        return;
    }
    
    // for an AcceptCallBack, the data parameter is a pointer to a CFSocketNativeHandle
    CFSocketNativeHandle nativeSocketHandle = *(CFSocketNativeHandle*)data;
    
    [server handleNewNativeSocket:nativeSocketHandle];
}


#pragma mark Sockets and streams

- (BOOL)createServer {
    //// PART 1: Create a socket that can accept connections
    
    // Socket context
    //  struct CFSocketContext {
    //   CFIndex version;
    //   void *info;
    //   CFAllocatorRetainCallBack retain;
    //   CFAllocatorReleaseCallBack release;
    //   CFAllocatorCopyDescriptionCallBack copyDescription;
    //  };
    CFSocketContext socketCtxt = {0, (__bridge void *)(self), NULL, NULL, NULL};
    
    _listeningSocket = CFSocketCreate(
                                      kCFAllocatorDefault,
                                      PF_INET,        // The protocol family for the socket
                                      SOCK_STREAM,    // The socket type to create
                                      IPPROTO_TCP,    // The protocol for the socket. TCP vs UDP.
                                      kCFSocketAcceptCallBack,  // New connections will be automatically accepted and the callback is called with the data argument being a pointer to a CFSocketNativeHandle of the child socket.
                                      (CFSocketCallBack)&serverAcceptCallback,
                                      &socketCtxt );
    
    // Previous call might have failed
    if (_listeningSocket == NULL) {
        return NO;
    }
    
    // getsockopt will return existing socket option value via this variable
    int existingValue = 1;
    
    // Make sure that same listening socket address gets reused after every connection
    setsockopt(CFSocketGetNative(_listeningSocket),
               SOL_SOCKET, SO_REUSEADDR, (void *)&existingValue,
               sizeof(existingValue));
    
    
    //// PART 2: Bind our socket to an endpoint.
    // We will be listening on all available interfaces/addresses.
    // Port will be assigned automatically by kernel.
    struct sockaddr_in socketAddress;
    memset(&socketAddress, 0, sizeof(socketAddress));
    socketAddress.sin_len = sizeof(socketAddress);
    socketAddress.sin_family = AF_INET;   // Address family (IPv4 vs IPv6)
    socketAddress.sin_port = 0;           // Actual port will get assigned automatically by kernel
    socketAddress.sin_addr.s_addr = htonl(INADDR_ANY);    // We must use "network byte order" format (big-endian) for the value here
    
    // Convert the endpoint data structure into something that CFSocket can use
    NSData *socketAddressData =
    [NSData dataWithBytes:&socketAddress length:sizeof(socketAddress)];
    
    // Bind our socket to the endpoint. Check if successful.
    if(CFSocketSetAddress(_listeningSocket,
                          (__bridge CFDataRef)socketAddressData) != kCFSocketSuccess ) {
        // Cleanup
        if(_listeningSocket != NULL) {
            CFRelease(_listeningSocket);
            _listeningSocket = NULL;
        }
        
        return NO;
    }
    
    
    //// PART 3: Find out what port kernel assigned to our socket
    // We need it to advertise our service via Bonjour
    NSData *socketAddressActualData =
    (__bridge NSData *)CFSocketCopyAddress(_listeningSocket);
    
    // Convert socket data into a usable structure
    struct sockaddr_in socketAddressActual;
    memcpy(&socketAddressActual, [socketAddressActualData bytes],
           [socketAddressActualData length]);
    
    self.port = ntohs(socketAddressActual.sin_port);
    
    //// PART 4: Hook up our socket to the current run loop
    CFRunLoopRef currentRunLoop = CFRunLoopGetCurrent();
    CFRunLoopSourceRef runLoopSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _listeningSocket, 0);
    CFRunLoopAddSource(currentRunLoop, runLoopSource, kCFRunLoopCommonModes);
    CFRelease(runLoopSource);
    
    return YES;
}


- (void)terminateServer {
    if(_listeningSocket != NULL) {
        CFSocketInvalidate(_listeningSocket);
		CFRelease(_listeningSocket);
		_listeningSocket = NULL;
    }
}


#pragma mark Bonjour

- (BOOL)publishService {
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:(__bridge NSString *)kCFBundleVersionKey];
    NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    NSString *serviceName = [NSString stringWithFormat:@"%@_%@", appName, version];
    
    // create new instance of netService
 	self.netService = [[NSNetService alloc]
                       initWithDomain:@"" type:@"_tweaks._tcp."
                       name:serviceName port:self.port];
    
	if(self.netService == nil)
		return NO;
    
    // Add service to current run loop
	[self.netService scheduleInRunLoop:[NSRunLoop currentRunLoop]
                               forMode:NSRunLoopCommonModes];
    
    // NetService will let us know about what's happening via delegate methods
	[self.netService setDelegate:self];
    
    // Publish the service
	[self.netService publish];
    
    return YES;
}


- (void)unpublishService {
    if(self.netService) {
        [self.netService stop];
        [self.netService removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        self.netService = nil;
    }
}

#pragma mark - NSNetServiceDelegate 

// Delegate method, called by NSNetService in case service publishing fails for whatever reason
- (void)netService:(NSNetService*)sender didNotPublish:(NSDictionary*)errorDict {
    if(sender != self.netService ) {
        return;
    }
    
    // Stop socket server
    [self terminateServer];
    
    // Stop Bonjour
    [self unpublishService];
    
    // Let delegate know about failure
    //[delegate serverFailed:self reason:@"Failed to publish service via Bonjour (duplicate server name?)"];
}

# pragma mark - FBTweakClientDelegate

- (void)clientConnectionAttemptFailed:(FBTweakClient *)client {
    [self.clients removeObject:client];
}

- (void)clientConnectionTerminated:(FBTweakClient *)client {
    [self.clients removeObject:client];
}

- (void)client:(FBTweakClient *)client receivedMessage:(NSDictionary *)message {
    NSString *messageType = message[@"type"];
    
    if([messageType isEqualToString:@"refresh"]) {
        [self refreshData:client];
    }
    else if([messageType isEqualToString:@"action"]) {
        FBTweakStore *tweakStore = [FBTweakStore sharedInstance];

        NSDictionary *tweakDictionary = message[@"tweak"];
        NSString *categoryName = tweakDictionary[@"category"];
        NSString *collectionName = tweakDictionary[@"collection"];
        NSString *tweakIdentifier = tweakDictionary[@"identifier"];

        for(FBTweakCategory *category in tweakStore.tweakCategories) {
            if([category.name isEqualToString:categoryName]) {
                for(FBTweakCollection *collection in category.tweakCollections) {
                    if([collection.name isEqualToString:collectionName]) {
                        for(FBTweak *tweak in collection.tweaks) {
                            if([tweak.identifier isEqualToString:tweakIdentifier]) {
                                dispatch_block_t block = tweak.defaultValue;
                                
                                if(block) {
                                    block();
                                }
                                break;
                            }
                        }
                        
                        break;
                    }
                }
                
                break;
            }
        }
    }
    else if([messageType isEqualToString:@"valueChanged"]) {
        FBTweakStore *tweakStore = [FBTweakStore sharedInstance];
        
        NSDictionary *tweakDictionary = message[@"tweak"];
        NSString *categoryName = tweakDictionary[@"category"];
        NSString *collectionName = tweakDictionary[@"collection"];
        NSString *tweakIdentifier = tweakDictionary[@"identifier"];
        
        for(FBTweakCategory *category in tweakStore.tweakCategories) {
            if([category.name isEqualToString:categoryName]) {
                for(FBTweakCollection *collection in category.tweakCollections) {
                    if([collection.name isEqualToString:collectionName]) {
                        for(FBTweak *tweak in collection.tweaks) {
                            if([tweak.identifier isEqualToString:tweakIdentifier]) {
                                tweak.currentValue = tweakDictionary[@"value"];
                                break;
                            }
                        }
                        
                        break;
                    }
                }
                
                break;
            }
        }
    }
}

@end
