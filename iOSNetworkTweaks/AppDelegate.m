//
//  AppDelegate.m
//  iOSNetworkTweaks
//
//  Created by Noah Hilt on 7/6/14.
//  Copyright (c) 2014 ___FULLUSERNAME___. All rights reserved.
//

#import "AppDelegate.h"
#import "FBTweakServer.h"

/*@implementation AppDelegate

FBTweakServer *_server;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    _server = [[FBTweakServer alloc] init];
    [_server start];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end*/

#import "FBTweak.h"
#import "FBTweakShakeWindow.h"
#import "FBTweakInline.h"
#import "FBTweakViewController.h"

@interface AppDelegate () <FBTweakObserver, FBTweakViewControllerDelegate>
@end

@implementation AppDelegate {
    UIWindow *_window;
    UIViewController *_rootViewController;
    
    UILabel *_label;
    FBTweak *_flipTweak;
}

FBTweakAction(@"Actions", @"Global", @"Hello", ^{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Hello" message:@"Global alert test." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"Done", nil];
    [alert show];
});

FBTweakServer *_server;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    FBTweakAction(@"Actions", @"Scoped", @"One", ^{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Hello" message:@"Scoped alert test #1." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"Done", nil];
        [alert show];
    });
    
    _server = [[FBTweakServer alloc] init];
    [_server start];
    
    _window = [[FBTweakShakeWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    _window.backgroundColor = [UIColor whiteColor];
    [_window makeKeyAndVisible];
    
    _rootViewController = [[UIViewController alloc] init];
    _rootViewController.view.backgroundColor = [UIColor colorWithRed:FBTweakValue(@"Window", @"Color", @"Red", 0.9, 0.0, 1.0)
                                                               green:FBTweakValue(@"Window", @"Color", @"Green", 0.9, 0.0, 1.0)
                                                                blue:FBTweakValue(@"Window", @"Color", @"Blue", 0.9, 0.0, 1.0)
                                                               alpha:1.0];
    _window.rootViewController = _rootViewController;
    
    _label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, _window.bounds.size.width, _window.bounds.size.height * 0.75)];
    _label.textAlignment = NSTextAlignmentCenter;
    _label.numberOfLines = 0;
    _label.userInteractionEnabled = YES;
    _label.backgroundColor = [UIColor clearColor];
    _label.textColor = [UIColor blackColor];
    _label.font = [UIFont systemFontOfSize:FBTweakValue(@"Content", @"Text", @"Size", 60.0)];
    FBTweakBind(_label, text, @"Content", @"Text", @"String", @"Tweaks");
    FBTweakBind(_label, alpha, @"Content", @"Text", @"Alpha", 0.5, 0.0, 1.0);
    [_rootViewController.view addSubview:_label];
    
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(labelTapped)];
    [_label addGestureRecognizer:tapRecognizer];
    
    _flipTweak = FBTweakInline(@"Window", @"Effects", @"Upside Down", NO);
    [_flipTweak addObserver:self];
    
    CGRect tweaksButtonFrame = _window.bounds;
    tweaksButtonFrame.origin.y = _label.bounds.size.height;
    tweaksButtonFrame.size.height = tweaksButtonFrame.size.height - _label.bounds.size.height;
    UIButton *tweaksButton = [[UIButton alloc] initWithFrame:tweaksButtonFrame];
    [tweaksButton setTitle:@"Show Tweaks" forState:UIControlStateNormal];
    [tweaksButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [tweaksButton addTarget:self action:@selector(buttonTapped) forControlEvents:UIControlEventTouchUpInside];
    [_rootViewController.view addSubview:tweaksButton];
    
    FBTweak *animationDurationTweak = FBTweakInline(@"Content", @"Animation", @"Duration", 0.5);
    animationDurationTweak.stepValue = [NSNumber numberWithFloat:0.005f];
    animationDurationTweak.precisionValue = [NSNumber numberWithFloat:3.0f];
    
    
    FBTweakAction(@"Actions", @"Scoped", @"Two", ^{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Hello" message:@"Scoped alert test #2." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"Done", nil];
        [alert show];
    });
    
    return YES;
}

- (void)tweakDidChange:(FBTweak *)tweak
{
    if (tweak == _flipTweak) {
        _window.layer.sublayerTransform = CATransform3DMakeScale(1.0, [_flipTweak.currentValue boolValue] ? -1.0 : 1.0, 1.0);
    }
}

- (void)buttonTapped
{
    FBTweakViewController *viewController = [[FBTweakViewController alloc] initWithStore:[FBTweakStore sharedInstance]];
    viewController.tweaksDelegate = self;
    [_window.rootViewController presentViewController:viewController animated:YES completion:NULL];
}

- (void)tweakViewControllerPressedDone:(FBTweakViewController *)tweakViewController
{
    [tweakViewController dismissViewControllerAnimated:YES completion:NULL];
}

- (void)labelTapped
{
    NSTimeInterval duration = FBTweakValue(@"Content", @"Animation", @"Duration", 0.5);
    [UIView animateWithDuration:duration animations:^{
        CGFloat scale = FBTweakValue(@"Content", @"Animation", @"Scale", 2.0);
        _label.transform = CGAffineTransformMakeScale(scale, scale);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:duration animations:^{
            _label.transform = CGAffineTransformIdentity;
        }];
    }];
}

@end
