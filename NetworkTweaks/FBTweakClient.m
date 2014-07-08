//
//  FBTweakClient.m
//  NetworkTweaks
//
//  Created by Noah Hilt on 7/6/14.
//  Copyright (c) 2014 ___FULLUSERNAME___. All rights reserved.
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

// Initialize, empty
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


// Connect using whatever connection info that was passed during initialization
- (BOOL)connect {
    if(self.host != nil) {
        // Bind read/write streams to a new socket
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, (__bridge CFStringRef)self.host,
                                           (UInt32)self.port, &_readStream, &_writeStream);
        
        // Do the rest
        if([self setupSocketStreams]) {
            if([self.delegate respondsToSelector:@selector(clientConnectionAttemptSucceeded:)]) {
                [self.delegate clientConnectionAttemptSucceeded:self];
            }
            
            return YES;
        }
    }
    else if(self.connectedSocketHandle != -1 ) {
        // Bind read/write streams to a socket represented by a native socket handle
        CFStreamCreatePairWithSocket(kCFAllocatorDefault, self.connectedSocketHandle,
                                     &_readStream, &_writeStream);
        
        // Do the rest
        if([self setupSocketStreams]) {
            if([self.delegate respondsToSelector:@selector(clientConnectionAttemptSucceeded:)]) {
                [self.delegate clientConnectionAttemptSucceeded:self];
            }
            
            return YES;
        }
    }
    else if(self.netService != nil) {
        // Still need to resolve?
        if(self.netService.hostName != nil) {
            CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,
                                               (__bridge CFStringRef)self.netService.hostName, (UInt32)self.netService.port, &_readStream, &_writeStream);
            return [self setupSocketStreams];
        }
        
        // Start resolving
        self.netService.delegate = self;
        [self.netService resolveWithTimeout:5.0];
        return YES;
    }
    
    return NO;
}


// Further setup socket streams that were created by one of our 'init' methods
- (BOOL)setupSocketStreams {
    // Make sure streams were created correctly
    if (_readStream == NULL || _writeStream == NULL) {
        [self close];
        return NO;
    }
    
    // Create buffers
    _incomingDataBuffer = [[NSMutableData alloc] init];
    _outgoingDataBuffer = [[NSMutableData alloc] init];
    
    // Indicate that we want socket to be closed whenever streams are closed
    CFReadStreamSetProperty(_readStream, kCFStreamPropertyShouldCloseNativeSocket,
                            kCFBooleanTrue);
    CFWriteStreamSetProperty(_writeStream, kCFStreamPropertyShouldCloseNativeSocket,
                             kCFBooleanTrue);
    
    // We will be handling the following stream events
    CFOptionFlags registeredEvents = kCFStreamEventOpenCompleted |
    kCFStreamEventHasBytesAvailable | kCFStreamEventCanAcceptBytes |
    kCFStreamEventEndEncountered | kCFStreamEventErrorOccurred;
    
    // Setup stream context - reference to 'self' will be passed to stream event handling callbacks
    CFStreamClientContext ctx = {0, (__bridge void *)(self), NULL, NULL, NULL};
    
    // Specify callbacks that will be handling stream events
    CFReadStreamSetClient(_readStream, registeredEvents, readStreamEventHandler, &ctx);
    CFWriteStreamSetClient(_writeStream, registeredEvents, writeStreamEventHandler, &ctx);
    
    // Schedule streams with current run loop
    CFReadStreamScheduleWithRunLoop(_readStream, CFRunLoopGetCurrent(),
                                    kCFRunLoopCommonModes);
    CFWriteStreamScheduleWithRunLoop(_writeStream, CFRunLoopGetCurrent(),
                                     kCFRunLoopCommonModes);
    
    // Open both streams
    if(!CFReadStreamOpen(_readStream) || ! CFWriteStreamOpen(_writeStream)) {
        [self close];
        return NO;
    }
    
    return YES;
}


// Close connection
- (void)close {
    // Cleanup read stream
    if(_readStream != NULL) {
        CFReadStreamUnscheduleFromRunLoop(_readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
        CFReadStreamClose(_readStream);
        CFRelease(_readStream);
        _readStream = NULL;
    }
    
    // Cleanup write stream
    if(_writeStream != NULL) {
        CFWriteStreamUnscheduleFromRunLoop(_writeStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
        CFWriteStreamClose(_writeStream);
        CFRelease(_writeStream);
        _writeStream = NULL;
    }
    
    // Cleanup buffers
    _incomingDataBuffer = nil;
    _outgoingDataBuffer = nil;
    
    self.netService.delegate = nil;
    [self.netService stop];
    self.netService = nil;
    
    // Reset all other variables
    [self clean];
}


// Send network message
- (void)sendNetworkPacket:(NSDictionary *)packet {
    // Encode packet
    NSData *rawPacket = [NSKeyedArchiver archivedDataWithRootObject:packet];
    
    // Write header: lengh of raw packet
    int packetLength = (int)[rawPacket length];
    [_outgoingDataBuffer appendBytes:&packetLength length:sizeof(int)];
    
    // Write body: encoded NSDictionary
    [_outgoingDataBuffer appendData:rawPacket];
    
    // Try to write to stream
    [self writeOutgoingBufferToStream];
}


#pragma mark Read stream methods

// Dispatch readStream events
void readStreamEventHandler(CFReadStreamRef stream, CFStreamEventType eventType, void *info) {
    FBTweakClient *client = (__bridge FBTweakClient *)info;
    [client readStreamHandleEvent:eventType];
}


// Handle events from the read stream
- (void)readStreamHandleEvent:(CFStreamEventType)event {
    // Stream successfully opened
    if(event == kCFStreamEventOpenCompleted) {
        _readStreamOpen = YES;
    }
    // New data has arrived
    else if(event == kCFStreamEventHasBytesAvailable) {
        // Read as many bytes from the stream as possible and try to extract meaningful packets
        [self readFromStreamIntoIncomingBuffer];
    }
    // Connection has been terminated or error encountered (we treat them the same way)
    else if(event == kCFStreamEventEndEncountered || event == kCFStreamEventErrorOccurred) {
        // Clean everything up
        [self close];
        
        // If we haven't connected yet then our connection attempt has failed
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


// Read as many bytes from the stream as possible and try to extract meaningful packets
- (void)readFromStreamIntoIncomingBuffer {
    // Temporary buffer to read data into
    UInt8 buf[1024];
    
    // Try reading while there is data
    while(CFReadStreamHasBytesAvailable(_readStream) ) {
        CFIndex len = CFReadStreamRead(_readStream, buf, sizeof(buf));
        if ( len <= 0 ) {
            // Either stream was closed or error occurred. Close everything up and treat this as "connection terminated"
            [self close];
            
            if([self.delegate respondsToSelector:@selector(clientConnectionTerminated:)]) {
                [self.delegate clientConnectionTerminated:self];
            }
            return;
        }
        
        [_incomingDataBuffer appendBytes:buf length:len];
    }
    
    // Try to extract packets from the buffer.
    //
    // Protocol: header + body
    //  header: an integer that indicates length of the body
    //  body: bytes that represent encoded NSDictionary
    
    // We might have more than one message in the buffer - that's why we'll be reading it inside the while loop
    while(YES) {
        // Did we read the header yet?
        if(_packetBodySize == -1) {
            // Do we have enough bytes in the buffer to read the header?
            if([_incomingDataBuffer length] >= sizeof(int)) {
                // extract length
                memcpy(&_packetBodySize, [_incomingDataBuffer bytes], sizeof(int));
                
                // remove that chunk from buffer
                NSRange rangeToDelete = {0, sizeof(int)};
                [_incomingDataBuffer replaceBytesInRange:rangeToDelete withBytes:NULL length:0];
            }
            else {
                // We don't have enough yet. Will wait for more data.
                break;
            }
        }
        
        // We should now have the header. Time to extract the body.
        if([_incomingDataBuffer length] >= _packetBodySize) {
            // We now have enough data to extract a meaningful packet.
            NSData *raw = [NSData dataWithBytes:[_incomingDataBuffer bytes] length:_packetBodySize];
            NSDictionary *packet = [NSKeyedUnarchiver unarchiveObjectWithData:raw];
            
            if([self.delegate respondsToSelector:@selector(client:receivedMessage:)]) {
                [self.delegate client:self receivedMessage:packet];
            }

            // Remove that chunk from buffer
            NSRange rangeToDelete = {0, _packetBodySize};
            [_incomingDataBuffer replaceBytesInRange:rangeToDelete withBytes:NULL length:0];
            
            // We have processed the packet. Resetting the state.
            _packetBodySize = -1;
        }
        else {
            // Not enough data yet. Will wait.
            break;
        }
    }
}


#pragma mark Write stream methods

// Dispatch writeStream event handling
void writeStreamEventHandler(CFWriteStreamRef stream, CFStreamEventType eventType, void *info) {
    FBTweakClient* client = (__bridge FBTweakClient *)info;
    [client writeStreamHandleEvent:eventType];
}


// Handle events from the write stream
- (void)writeStreamHandleEvent:(CFStreamEventType)event {
    // Stream successfully opened
    if(event == kCFStreamEventOpenCompleted) {
        _writeStreamOpen = YES;
    }
    // Stream has space for more data to be written
    else if(event == kCFStreamEventCanAcceptBytes) {
        // Write whatever data we have, as much as stream can handle
        [self writeOutgoingBufferToStream];
    }
    // Connection has been terminated or error encountered (we treat them the same way)
    else if(event == kCFStreamEventEndEncountered || event == kCFStreamEventErrorOccurred) {
        // Clean everything up
        [self close];
        
        // If we haven't connected yet then our connection attempt has failed
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


// Write whatever data we have, as much of it as stream can handle
- (void)writeOutgoingBufferToStream {
    // Is connection open?
    if(!_readStreamOpen || !_writeStreamOpen ) {
        // No, wait until everything is operational before pushing data through
        return;
    }
    
    // Do we have anything to write?
    if([_outgoingDataBuffer length] == 0 ) {
        return;
    }
    
    // Can stream take any data in?
    if(!CFWriteStreamCanAcceptBytes(_writeStream) ) {
        return;
    }
    
    // Write as much as we can
    CFIndex writtenBytes = CFWriteStreamWrite(_writeStream, [_outgoingDataBuffer bytes], [_outgoingDataBuffer length]);
    
    if(writtenBytes == -1) {
        // Error occurred. Close everything up.
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

// Called if we weren't able to resolve net service
- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict {
    if(sender != self.netService) {
        return;
    }
    
    [self close];

    if([self.delegate respondsToSelector:@selector(clientConnectionAttemptFailed:)]) {
        [self.delegate clientConnectionAttemptFailed:self];
    }
}


// Called when net service has been successfully resolved
- (void)netServiceDidResolveAddress:(NSNetService *)sender {
    if(sender != self.netService) {
        return;
    }
    
    // Save connection info
    self.host = self.netService.hostName;
    self.port = self.netService.port;
    
    // Don't need the service anymore
    self.netService.delegate = nil;
    self.netService = nil;
    
    // Connect!
    if(![self connect]) {
        [self close];

        if([self.delegate respondsToSelector:@selector(clientConnectionAttemptFailed:)]) {
            [self.delegate clientConnectionAttemptFailed:self];
        }
    }
}

@end