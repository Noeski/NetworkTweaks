//
//  AppDelegate.h
//  NetworkTweaks
//
//  Created by Noah Hilt on 7/6/14.
//  Copyright (c) 2014 ___FULLUSERNAME___. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FBTweakClient.h"
#import "FBTweakTableViewCell.h"

@interface AppDelegate : NSObject <NSApplicationDelegate,
NSNetServiceBrowserDelegate,
NSTableViewDataSource,
NSTableViewDelegate,
FBTweakClientDelegate,
FBTweakTableViewCellDelegate> 
@property (nonatomic, strong) IBOutlet NSWindow *window;
@property (nonatomic, strong) IBOutlet NSPopUpButton *popupButton;
@property (nonatomic, strong) IBOutlet NSTableView *tableView;
@property (nonatomic, strong) IBOutlet NSTableView *categoryTableView;

- (BOOL)start;
- (void)stop;
@end
