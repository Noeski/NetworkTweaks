//
//  AppDelegate.m
//  NetworkTweaks
//
//  Created by Noah Hilt on 7/6/14.
//  Copyright (c) 2014 ___FULLUSERNAME___. All rights reserved.
//

#import "AppDelegate.h"
#import "FBTweakClient.h"
#import "FBTweakCategoryTableViewCell.h"
#import "FBTweakData.h"

@interface FBTweakTableView : NSTableView
@end

@implementation FBTweakTableView
- (BOOL)validateProposedFirstResponder:(NSResponder *)responder forEvent:(NSEvent *)event {
    return YES;
}
@end

@interface AppDelegate()
@property (nonatomic, strong) NSNetServiceBrowser *netServiceBrowser;
@property (nonatomic, strong) NSMutableArray *servers;
@property (nonatomic, strong) FBTweakClient *client;
@property (nonatomic, strong) NSArray *tweakCategories;
@property (nonatomic, strong) NSArray *tweakCollections;
@property (nonatomic, strong) NSArray *tweaks;
@end

@implementation AppDelegate

- (id)init {
    if(self = [super init]) {
        _servers = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self.categoryTableView registerNib:[[NSNib alloc] initWithNibNamed:@"FBTweakCategoryTableViewCell" bundle:nil] forIdentifier:@"FBTweakCategoryTableViewCell"];
    [self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"FBTweakTableViewCell" bundle:nil] forIdentifier:@"FBTweakTableViewCell"];
    [self reloadData];
    [self start];
}

- (BOOL)start {
    if(self.netServiceBrowser) {
        [self stop];
    }
    
	self.netServiceBrowser = [[NSNetServiceBrowser alloc] init];
    
	if(!self.netServiceBrowser) {
		return NO;
	}
    
	self.netServiceBrowser.delegate = self;
	[self.netServiceBrowser searchForServicesOfType:@"_tweaks._tcp." inDomain:@""];
    
    return YES;
}

- (void)stop {
    if(!self.netServiceBrowser) {
        return;
    }
    
    [self.netServiceBrowser stop];
    self.netServiceBrowser = nil;
    
    [self.servers removeAllObjects];
}

- (void)reloadData {
    [self.popupButton removeAllItems];
    [self.popupButton addItemWithTitle:@"No Server Selected"];
    
    for(NSNetService *server in self.servers) {
        [self.popupButton addItemWithTitle:server.name];
    }
    
    if(!self.client && [self.servers count]) {
        [self.popupButton selectItemAtIndex:1];
        [self serverSelected:self.popupButton];
    }
}

- (void)setTweakCategories:(NSArray *)tweakCategories {
    if(tweakCategories != _tweakCategories) {
        _tweakCategories = tweakCategories;
        [self.categoryTableView reloadData];
    }
}

- (void)setTweaks:(NSArray *)tweaks {
    if(tweaks != _tweaks) {
        _tweaks = tweaks;
        [self.tableView reloadData];
    }
}

- (IBAction)serverSelected:(NSPopUpButton *)sender {
    NSInteger selectedIndex = [sender indexOfSelectedItem];
    
    if(selectedIndex < 0 || selectedIndex > [self.servers count])
        return;
    
    if(selectedIndex == 0) {
        if(self.client) {
            [self.client close];
            self.client = nil;
        }
    }
    else {
        NSNetService *selectedServer = self.servers[selectedIndex-1];
        
        if(self.client) {
            [self.client close];
            self.client = nil;
        }
        
        self.client = [[FBTweakClient alloc] initWithNetService:selectedServer];
        self.client.delegate = self;

        if(![self.client connect]) {
            self.client = nil;
        }
    }
}

- (IBAction)refresh:(id)sender {
    if(!self.client)
        return;
    
    [self.client sendNetworkPacket:@{@"type" : @"refresh"}];
}

#pragma mark - NSNetServiceBrowserDelegate

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindService:(NSNetService *)netService moreComing:(BOOL)moreServicesComing {
    if(![self.servers containsObject:netService]) {
        [self.servers addObject:netService];
    }
    
    if(moreServicesComing) {
        return;
    }
    
    [self reloadData];
}


- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didRemoveService:(NSNetService *)netService moreComing:(BOOL)moreServicesComing {
    [self.servers removeObject:netService];
    
    if(moreServicesComing) {
        return;
    }
    
    [self reloadData];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if(tableView == self.categoryTableView) {
        return [self.tweakCategories count];
    }
    else {
        return [self.tweaks count];
    }
}

#pragma mark - NSTableViewDelegate

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row {
    if(tableView == self.categoryTableView) {
        FBTweakCategory *category = self.tweakCategories[row];
        FBTweakCategoryTableViewCell *cell = [tableView makeViewWithIdentifier:@"FBTweakCategoryTableViewCell" owner:self];
        cell.nameLabel.stringValue = category.name;
        
        return cell;
    }
    else {
        FBTweakTableViewCell *cell = [tableView makeViewWithIdentifier:@"FBTweakTableViewCell" owner:self];
        cell.delegate = self;
        cell.tweakData = [self.tweaks objectAtIndex:row];
        
        return cell;
    }
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    return nil;
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)rowIndex {
    if(tableView == self.categoryTableView) {
        return YES;
    }
    else {
        return NO;
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSTableView *tableView = notification.object;
    
    if(tableView == self.categoryTableView) {
        NSInteger selectedIndex = [tableView selectedRow];
        FBTweakCategory *selectedCategory = nil;
        
        if(selectedIndex >= 0 && selectedIndex < [self.tweakCategories count]) {
            selectedCategory = self.tweakCategories[selectedIndex];
        }
        
        NSMutableArray *mutableTweaks = [[NSMutableArray alloc] init];
        
        for(FBTweakCollection *collection in selectedCategory.collections) {
            [mutableTweaks addObjectsFromArray:collection.tweaks];
        }
        
        self.tweaks = mutableTweaks;
    }
}

#pragma mark - FBTweakClientDelegate

- (void)clientConnectionAttemptSucceeded:(FBTweakClient *)client {
    NSLog(@"Client succeeded");

    if(client != self.client)
        return;
    
    [self refresh:nil];
}

- (void)clientConnectionAttemptFailed:(FBTweakClient *)client {
    NSLog(@"Client failed");

    if(client != self.client)
        return;
}

- (void)clientConnectionTerminated:(FBTweakClient *)client {
    NSLog(@"Client terminated");

    if(client != self.client)
        return;
}

- (void)client:(FBTweakClient *)client receivedMessage:(NSDictionary *)message {
    NSLog(@"Client received message");

    if(client != self.client)
        return;
    
    NSArray *categories = message[@"categories"];
    NSMutableArray *mutableCategories = [[NSMutableArray alloc] initWithCapacity:[categories count]];

    for(NSDictionary *category in categories) {
        FBTweakCategory *tweakCategory = [[FBTweakCategory alloc] initWithDictionary:category];
        
        [mutableCategories addObject:tweakCategory];
    }
    
    self.tweakCategories = mutableCategories;
}

#pragma mark - FBTweakTableViewCellDelegate

- (void)tweakDidChange:(FBTweakData *)tweak {
    if(!self.client)
        return;
    
    [self.client sendNetworkPacket:@{@"type" : @"valueChanged",
                                     @"tweak" : @{@"name" : tweak.name,
                                                  @"identifier" : tweak.identifier,
                                                  @"collection" : tweak.collection.name,
                                                  @"category" : tweak.collection.category.name,
                                                  @"value" : tweak.currentValue}}];
}

- (void)tweakAction:(FBTweakData *)tweak {
    if(!self.client)
        return;
    
    [self.client sendNetworkPacket:@{@"type" : @"action",
                                     @"tweak" : @{@"name" : tweak.name,
                                                  @"identifier" : tweak.identifier,
                                                  @"collection" : tweak.collection.name,
                                                  @"category" : tweak.collection.category.name}}];
}

@end
