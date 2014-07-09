//
//  FBTweakClient.m
//  NetworkTweaks
//
//  Created by Noah Hilt on 7/6/14.
//  Copyright (c) 2014 Noah Hilt. All rights reserved.
//

#import "FBTweakClient.h"

// Declare C callback functions
void readStreamEventHandler(CFReadStreamRef stream, CFStreamEventType eventType, void *info);
void writeStreamEventHandler(CFWriteStreamRef stream, CFStreamEventType eventType, void *info);

@interface FBTweakClient() {
  // Read stream
  CFReadStreamRef _readStream;
  BOOL _readStreamOpen;
  NSMutableData *_incomingDataBuffer;
  int _packetBodySize;
  
  // Write stream
  CFWriteStreamRef _writeStream;
  BOOL _writeStreamOpen;
  NSMutableData *_outgoingDataBuffer;
}

@property(nonatomic, strong) NSString *host;
@property(nonatomic, assign) NSInteger port;
@property(nonatomic, assign) CFSocketNativeHandle connectedSocketHandle;
@property(nonatomic, strong) NSNetService *netService;

- (void)clean;
- (BOOL)setupSocketStreams;

- (void)readStreamHandleEvent:(CFStreamEventType)event;
- (void)writeStreamHandleEvent:(CFStreamEventType)event;

- (void)readFromStreamIntoIncomingBuffer;

- (void)writeOutgoingBufferToStream;
@end


@implementation FBTweakClient

- (void)clean {
  _readStream = NULL;
  _readStreamOpen = NO;
  
  _writeStream = nil;
  _writeStreamOpen = NO;
  
  _incomingDataBuffer = nil;
  _outgoingDataBuffer = nil;
  
  self.host = nil;
  self.connectedSocketHandle = -1;
  _packetBodySize = -1;
}

- (id)initWithNativeSocketHandle:(CFSocketNativeHandle)nativeSocketHandle {
  if(self = [super init]) {
    [self clean];
    
    _connectedSocketHandle = nativeSocketHandle;
  }
  
  return self;
}

- (id)initWithNetService:(NSNetService *)netService {
  if(self = [super init]) {
    [self clean];
    
    if(_netService.hostName != nil) {
      _host = _netService.hostName;
      _port = _netService.port;
    }
    else {
      _netService = netService;
    }
  }
  
  return self;
}

- (BOOL)connect {
  if(self.netService.hostName) {
    self.host = self.netService.hostName;
    self.port = self.netService.port;
    
    self.netService.delegate = nil;
    self.netService = nil;
  }
  
  if(self.host != nil) {
    CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, (__bridge CFStringRef)self.host,
                                       (UInt32)self.port, &_readStream, &_writeStream);
    
    if([self setupSocketStreams]) {
      if([self.delegate respondsToSelector:@selector(clientConnectionAttemptSucceeded:)]) {
        [self.delegate clientConnectionAttemptSucceeded:self];
      }
      
      return YES;
    }
  }
  else if(self.connectedSocketHandle != -1 ) {
    CFStreamCreatePairWithSocket(kCFAllocatorDefault, self.connectedSocketHandle,
                                 &_readStream, &_writeStream);
    
    if([self setupSocketStreams]) {
      if([self.delegate respondsToSelector:@selector(clientConnectionAttemptSucceeded:)]) {
        [self.delegate clientConnectionAttemptSucceeded:self];
      }
      
      return YES;
    }
  }
  else if(self.netService != nil) {
    self.netService.delegate = self;
    [self.netService resolveWithTimeout:5.0];
    
    return YES;
  }
  
  return NO;
}

- (BOOL)setupSocketStreams {
  if(_readStream == NULL || _writeStream == NULL) {
    [self close];
    return NO;
  }
  
  _incomingDataBuffer = [[NSMutableData alloc] initWithCapacity:2048];
  _outgoingDataBuffer = [[NSMutableData alloc] initWithCapacity:2048];
  
  CFReadStreamSetProperty(_readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
  CFWriteStreamSetProperty(_writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
  
  CFOptionFlags registeredEvents = kCFStreamEventOpenCompleted |
  kCFStreamEventHasBytesAvailable | kCFStreamEventCanAcceptBytes |
  kCFStreamEventEndEncountered | kCFStreamEventErrorOccurred;
  
  CFStreamClientContext ctx = {0, (__bridge void *)(self), NULL, NULL, NULL};
  
  CFReadStreamSetClient(_readStream, registeredEvents, readStreamEventHandler, &ctx);
  CFWriteStreamSetClient(_writeStream, registeredEvents, writeStreamEventHandler, &ctx);
  
  CFReadStreamScheduleWithRunLoop(_readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
  CFWriteStreamScheduleWithRunLoop(_writeStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
  
  if(!CFReadStreamOpen(_readStream) || ! CFWriteStreamOpen(_writeStream)) {
    [self close];
    return NO;
  }
  
  return YES;
}


- (void)close {
  if(_readStream) {
    CFReadStreamUnscheduleFromRunLoop(_readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    CFReadStreamClose(_readStream);
    CFRelease(_readStream);
    _readStream = NULL;
  }
  
  if(_writeStream) {
    CFWriteStreamUnscheduleFromRunLoop(_writeStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    CFWriteStreamClose(_writeStream);
    CFRelease(_writeStream);
    _writeStream = NULL;
  }
  
  _incomingDataBuffer = nil;
  _outgoingDataBuffer = nil;
  
  self.netService.delegate = nil;
  [self.netService stop];
  self.netService = nil;
  
  [self clean];
}

- (void)sendNetworkPacket:(NSDictionary *)packet {
  NSData *rawPacket = [NSKeyedArchiver archivedDataWithRootObject:packet];
  
  int packetLength = (int)[rawPacket length];
  [_outgoingDataBuffer appendBytes:&packetLength length:sizeof(int)];
  [_outgoingDataBuffer appendData:rawPacket];
  
  [self writeOutgoingBufferToStream];
}

#pragma mark - Read stream methods

void readStreamEventHandler(CFReadStreamRef stream, CFStreamEventType eventType, void *info) {
  FBTweakClient *client = (__bridge FBTweakClient *)info;
  [client readStreamHandleEvent:eventType];
}

- (void)readStreamHandleEvent:(CFStreamEventType)event {
  if(event == kCFStreamEventOpenCompleted) {
    _readStreamOpen = YES;
  }
  else if(event == kCFStreamEventHasBytesAvailable) {
    [self readFromStreamIntoIncomingBuffer];
  }
  else if(event == kCFStreamEventEndEncountered || event == kCFStreamEventErrorOccurred) {
    [self close];
    
    if(!_readStreamOpen || !_writeStreamOpen) {
      if([self.delegate respondsToSelector:@selector(clientConnectionAttemptFailed:)]) {
        [self.delegate clientConnectionAttemptFailed:self];
      }
    }
    else {
      if([self.delegate respondsToSelector:@selector(clientConnectionTerminated:)]) {
        [self.delegate clientConnectionTerminated:self];
      }
    }
  }
}

- (void)readFromStreamIntoIncomingBuffer {
  UInt8 buf[1024];
  
  while(CFReadStreamHasBytesAvailable(_readStream) ) {
    CFIndex len = CFReadStreamRead(_readStream, buf, sizeof(buf));
    if(len <= 0) {
      [self close];
      
      if([self.delegate respondsToSelector:@selector(clientConnectionTerminated:)]) {
        [self.delegate clientConnectionTerminated:self];
      }
      return;
    }
    
    [_incomingDataBuffer appendBytes:buf length:len];
  }
  
  while(YES) {
    if(_packetBodySize == -1) {
      if([_incomingDataBuffer length] >= sizeof(int)) {
        memcpy(&_packetBodySize, [_incomingDataBuffer bytes], sizeof(int));
        
        NSRange rangeToDelete = {0, sizeof(int)};
        [_incomingDataBuffer replaceBytesInRange:rangeToDelete withBytes:NULL length:0];
      }
      else {
        break;
      }
    }
    
    if([_incomingDataBuffer length] >= _packetBodySize) {
      NSData *raw = [NSData dataWithBytes:[_incomingDataBuffer bytes] length:_packetBodySize];
      NSDictionary *packet = [NSKeyedUnarchiver unarchiveObjectWithData:raw];
      
      if([self.delegate respondsToSelector:@selector(client:receivedMessage:)]) {
        [self.delegate client:self receivedMessage:packet];
      }
      
      NSRange rangeToDelete = {0, _packetBodySize};
      [_incomingDataBuffer replaceBytesInRange:rangeToDelete withBytes:NULL length:0];
      
      _packetBodySize = -1;
    }
    else {
      break;
    }
  }
}

#pragma mark - Write stream methods

void writeStreamEventHandler(CFWriteStreamRef stream, CFStreamEventType eventType, void *info) {
  FBTweakClient* client = (__bridge FBTweakClient *)info;
  [client writeStreamHandleEvent:eventType];
}

- (void)writeStreamHandleEvent:(CFStreamEventType)event {
  if(event == kCFStreamEventOpenCompleted) {
    _writeStreamOpen = YES;
  }
  else if(event == kCFStreamEventCanAcceptBytes) {
    [self writeOutgoingBufferToStream];
  }
  else if(event == kCFStreamEventEndEncountered || event == kCFStreamEventErrorOccurred) {
    [self close];
    
    if(!_readStreamOpen || !_writeStreamOpen) {
      if([self.delegate respondsToSelector:@selector(clientConnectionAttemptFailed:)]) {
        [self.delegate clientConnectionAttemptFailed:self];
      }
    }
    else {
      if([self.delegate respondsToSelector:@selector(clientConnectionTerminated:)]) {
        [self.delegate clientConnectionTerminated:self];
      }
    }
  }
}

- (void)writeOutgoingBufferToStream {
  if(!_readStreamOpen || !_writeStreamOpen ) {
    return;
  }
  
  if([_outgoingDataBuffer length] == 0 ) {
    return;
  }
  
  if(!CFWriteStreamCanAcceptBytes(_writeStream) ) {
    return;
  }
  
  CFIndex writtenBytes = CFWriteStreamWrite(_writeStream, [_outgoingDataBuffer bytes], [_outgoingDataBuffer length]);
  
  if(writtenBytes == -1) {
    [self close];
    
    if([self.delegate respondsToSelector:@selector(clientConnectionTerminated:)]) {
      [self.delegate clientConnectionTerminated:self];
    }
    return;
  }
  
  NSRange range = {0, writtenBytes};
  [_outgoingDataBuffer replaceBytesInRange:range withBytes:NULL length:0];
}

#pragma mark - NSNetServiceDelegate

- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict {
  if(sender != self.netService) {
    return;
  }
  
  [self close];
  
  if([self.delegate respondsToSelector:@selector(clientConnectionAttemptFailed:)]) {
    [self.delegate clientConnectionAttemptFailed:self];
  }
}

- (void)netServiceDidResolveAddress:(NSNetService *)sender {
  if(sender != self.netService) {
    return;
  }
  
  self.host = self.netService.hostName;
  self.port = self.netService.port;
  
  self.netService.delegate = nil;
  self.netService = nil;
  
  if(![self connect]) {
    [self close];
    
    if([self.delegate respondsToSelector:@selector(clientConnectionAttemptFailed:)]) {
      [self.delegate clientConnectionAttemptFailed:self];
    }
  }
}

@end