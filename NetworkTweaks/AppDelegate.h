//
//  AppDelegate.h
//  NetworkTweaks
//
//  Created by Noah Hilt on 7/6/14.
//  Copyright (c) 2014 ___FULLUSERNAME___. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FBTweakClient.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, NSNetServiceBrowserDelegate, NSTableViewDataSource, NSTableViewDelegate, FBTweakClientDelegate> {
    NSNetServiceBrowser *netServiceBrowser;
    NSMutableArray *servers;
    NSMutableArray *tweakCategories;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSPopUpButton *popupButton;
@property (assign) IBOutlet NSTableView *tableView;

- (BOOL)start;
- (void)stop;
@end
