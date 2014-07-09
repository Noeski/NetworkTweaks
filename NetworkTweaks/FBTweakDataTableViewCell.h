//
//  FBTweakDataTableViewCell.h
//  NetworkTweaks
//
//  Created by Noah Hilt on 7/7/14.
//  Copyright (c) 2014 Noah Hilt. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FBTweakData.h"

@protocol FBTweakDataTableViewCellDelegate<NSObject>
@optional
- (void)tweakDidChange:(FBTweakData *)tweak;
- (void)tweakAction:(FBTweakData *)tweak;
@end

@interface FBTweakDataTableViewCell : NSTableRowView<NSTextFieldDelegate>
@property (nonatomic, weak) id<FBTweakDataTableViewCellDelegate> delegate;
@property (nonatomic, strong) FBTweakData *tweakData;
@end
