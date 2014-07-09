//
//  AppDelegate.m
//  NetworkTweaks
//
//  Created by Noah Hilt on 7/6/14.
//  Copyright (c) 2014 Noah Hilt. All rights reserved.
//

#import "AppDelegate.h"
#import "FBTweakClient.h"
#import "FBTweakCategoryTableViewCell.h"
#import "FBTweakCollectionTableViewCell.h"
#import "FBTweakData.h"

@interface FBTweakTableView : NSTableView
@end

@implementation FBTweakTableView
- (BOOL)validateProposedFirstResponder:(NSResponder *)responder forEvent:(NSEvent *)event {
    return YES;
}
@end

@interface AppDelegate()
@property (nonatomic, assign) BOOL refreshing;
@property (nonatomic, strong) NSNetServiceBrowser *netServiceBrowser;
@property (nonatomic, strong) NSMutableArray *servers;
@property (nonatomic, strong) FBTweakClient *client;
@property (nonatomic, strong) NSArray *tweakCategories;
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
    [self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"FBTweakCollectionTableViewCell" bundle:nil] forIdentifier:@"FBTweakCollectionTableViewCell"];
    [self.tableView registerNib:[[NSNib alloc] initWithNibNamed:@"FBTweakDataTableViewCell" bundle:nil] forIdentifier:@"FBTweakDataTableViewCell"];
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
    
    if(selectedIndex < 0 || selectedIndex > [self.servers count] )
        return;
    
    self.refreshing = NO;
    self.tweaks = nil;
    self.tweakCategories = nil;
    
    if(self.client) {
        [self.client close];
        self.client = nil;
    }
    
    if(selectedIndex > 0) {
        NSNetService *selectedServer = self.servers[selectedIndex-1];
        
        self.client = [[FBTweakClient alloc] initWithNetService:selectedServer];
        self.client.delegate = self;

        if(![self.client connect]) {
            self.client = nil;
        }
    }
}

- (IBAction)refresh:(id)sender {
    if(!self.client || self.refreshing)
        return;
    
    self.refreshing = YES;

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

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    if(tableView == self.categoryTableView) {
        return [self.categoryTableView rowHeight];
    }
    else {
        id obj = self.tweaks[row];
        
        if([obj isKindOfClass:[FBTweakCollection class]]) {
            return 22;
        }
        else {
            return 28;
        }
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
        id obj = self.tweaks[row];
        
        if([obj isKindOfClass:[FBTweakCollection class]]) {
            FBTweakCollectionTableViewCell *cell = [tableView makeViewWithIdentifier:@"FBTweakCollectionTableViewCell" owner:self];
            cell.nameLabel.stringValue = [[obj name] uppercaseString];

            return cell;
        }
        else {
            FBTweakDataTableViewCell *cell = [tableView makeViewWithIdentifier:@"FBTweakDataTableViewCell" owner:self];
            cell.delegate = self;
            cell.tweakData = [self.tweaks objectAtIndex:row];
            
            return cell;
        }
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
            [mutableTweaks addObject:collection];
            [mutableTweaks addObjectsFromArray:collection.tweaks];
        }
        
        self.tweaks = mutableTweaks;
    }
}

#pragma mark - FBTweakClientDelegate

- (void)clientConnectionAttemptSucceeded:(FBTweakClient *)client {
    if(client != self.client)
        return;
    
    [self refresh:nil];
}

- (void)clientConnectionAttemptFailed:(FBTweakClient *)client {
    self.refreshing = NO;
}

- (void)clientConnectionTerminated:(FBTweakClient *)client {
    self.refreshing = NO;
}

- (void)client:(FBTweakClient *)client receivedMessage:(NSDictionary *)message {
    if(client != self.client)
        return;
    
    NSArray *categories = message[@"categories"];
    NSMutableArray *mutableCategories = [[NSMutableArray alloc] initWithCapacity:[categories count]];

    for(NSDictionary *category in categories) {
        FBTweakCategory *tweakCategory = [[FBTweakCategory alloc] initWithDictionary:category];
        
        [mutableCategories addObject:tweakCategory];
    }
    
    self.tweakCategories = mutableCategories;
    self.refreshing = NO;
}

#pragma mark - FBTweakDataTableViewCellDelegate

- (void)tweakDidChange:(FBTweakData *)tweak {
    if(!self.client || self.refreshing)
        return;
    
    [self.client sendNetworkPacket:@{@"type" : @"valueChanged",
                                     @"tweak" : @{@"name" : tweak.name,
                                                  @"identifier" : tweak.identifier,
                                                  @"collection" : tweak.collection.name,
                                                  @"category" : tweak.collection.category.name,
                                                  @"value" : tweak.currentValue}}];
}

- (void)tweakAction:(FBTweakData *)tweak {
    if(!self.client || self.refreshing)
        return;
    
    [self.client sendNetworkPacket:@{@"type" : @"action",
                                     @"tweak" : @{@"name" : tweak.name,
                                                  @"identifier" : tweak.identifier,
                                                  @"collection" : tweak.collection.name,
                                                  @"category" : tweak.collection.category.name}}];
}

@end
