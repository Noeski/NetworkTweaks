//
//  AppDelegate.m
//  NetworkTweaks
//
//  Created by Noah Hilt on 7/6/14.
//  Copyright (c) 2014 ___FULLUSERNAME___. All rights reserved.
//

#import "AppDelegate.h"
#import "FBTweakClient.h"

@interface AppDelegate() {
    FBTweakClient *_client;
}
@end

@implementation AppDelegate

- (id)init {
    if(self = [super init]) {
        servers = [[NSMutableArray alloc] init];
        tweakCategories = [[NSMutableArray alloc] init];
    }
    
    return self;
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self.tableView setDoubleAction:@selector(serverSelected)];
    [self start];
    [self reloadData];
}

- (BOOL)start {
    // Restarting?
    if(netServiceBrowser != nil) {
        [self stop];
    }
    
	netServiceBrowser = [[NSNetServiceBrowser alloc] init];
    
	if(!netServiceBrowser) {
		return NO;
	}
    
	netServiceBrowser.delegate = self;
	[netServiceBrowser searchForServicesOfType:@"_tweaks._tcp." inDomain:@""];
    
    return YES;
}


- (void)stop {
    if(netServiceBrowser == nil) {
        return;
    }
    
    [netServiceBrowser stop];
    netServiceBrowser = nil;
    
    [servers removeAllObjects];
}

- (void)reloadData {
    [self.popupButton removeAllItems];
    [self.popupButton addItemWithTitle:@"No Server Selected"];
    
    for(NSNetService *server in servers) {
        [self.popupButton addItemWithTitle:server.name];
    }
    
    if(!_client && [servers count]) {
        [self.popupButton selectItemAtIndex:1];
        [self serverSelected:self.popupButton];
    }
}

- (IBAction)serverSelected:(NSPopUpButton *)sender {
    NSInteger selectedIndex = [sender indexOfSelectedItem];
    
    if(selectedIndex < 0 || selectedIndex > [servers count])
        return;
    
    if(selectedIndex == 0) {
        if(_client) {
            [_client close];
            _client = nil;
        }
    }
    else {
        NSNetService *selectedServer = servers[selectedIndex-1];
        
        if(_client) {
            [_client close];
            _client = nil;
        }
        
        _client = [[FBTweakClient alloc] initWithNetService:selectedServer];
        
        if(![_client connect]) {
            _client = nil;
        }
        
        _client.delegate = self;
    }
}

- (void)serverSelected {
}

#pragma mark - NSNetServiceBrowserDelegate

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindService:(NSNetService *)netService moreComing:(BOOL)moreServicesComing {
    if(![servers containsObject:netService]) {
        [servers addObject:netService];
    }
    
    if(moreServicesComing) {
        return;
    }
    
    [self reloadData];
}


- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didRemoveService:(NSNetService *)netService moreComing:(BOOL)moreServicesComing {
    [servers removeObject:netService];
    
    if(moreServicesComing) {
        return;
    }
    
    [self reloadData];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [tweakCategories count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    return tweakCategories[row];
}

#pragma mark - FBTweakClientDelegate

- (void)clientConnectionAttemptFailed:(FBTweakClient *)client {
    if(client != _client)
        return;
}

- (void)clientConnectionTerminated:(FBTweakClient *)client {
    if(client != _client)
        return;
}

- (void)client:(FBTweakClient *)client receivedMessage:(NSDictionary *)message {
    if(client != _client)
        return;
    
    [tweakCategories removeAllObjects];
    
    NSArray *categories = message[@"categories"];
    for(NSDictionary *category in categories) {
        [tweakCategories addObject:category[@"name"]];
    }
    
    [self.tableView reloadData];
}

@end
