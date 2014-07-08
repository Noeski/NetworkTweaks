//
//  FBTweakTableViewCell.m
//  NetworkTweaks
//
//  Created by Noah Hilt on 7/7/14.
//  Copyright (c) 2014 Noah Hilt. All rights reserved.
//

#import "FBTweakTableViewCell.h"

@interface FBTweakTableViewCell()
@property (nonatomic, strong) IBOutlet NSTextField *nameLabel;
@property (nonatomic, strong) IBOutlet NSTextField *textField;
@property (nonatomic, strong) IBOutlet NSStepper *stepper;
@property (nonatomic, strong) IBOutlet NSButton *checkButton;
@property (nonatomic, strong) IBOutlet NSButton *actionButton;
@end

@implementation FBTweakTableViewCell

- (void)setTweakData:(FBTweakData *)tweakData {
    if(_tweakData != tweakData) {
        _tweakData = tweakData;
        
        self.nameLabel.stringValue = _tweakData.name;
        
        switch(_tweakData.type) {
            case FBTweakDataTypeBoolean:
                [self.textField setHidden:YES];
                [self.stepper setHidden:YES];
                [self.checkButton setHidden:NO];
                [self.actionButton setHidden:YES];
                break;
            
            case FBTweakDataTypeInteger:
                [self.textField setHidden:NO];
                [self.stepper setHidden:NO];
                [self.checkButton setHidden:YES];
                [self.actionButton setHidden:YES];

                if(self.tweakData.stepValue) {
                    self.stepper.increment = [self.tweakData.stepValue floatValue];
                }
                else {
                    self.stepper.increment = 1.0;
                }
                
                if(self.tweakData.minimumValue) {
                    self.stepper.minValue = [self.tweakData.minimumValue longLongValue];
                }
                else {
                    self.stepper.minValue = [self.tweakData.currentValue longLongValue] / 10.0;
                }
                
                if(self.tweakData.maximumValue) {
                    self.stepper.maxValue = [self.tweakData.maximumValue longLongValue];
                }
                else {
                    self.stepper.maxValue = [self.tweakData.currentValue longLongValue] * 10.0;
                }
                break;
            
            case FBTweakDataTypeReal:
                [self.textField setHidden:NO];
                [self.stepper setHidden:NO];
                [self.checkButton setHidden:YES];
                [self.actionButton setHidden:YES];

                if(self.tweakData.minimumValue) {
                    self.stepper.minValue = [self.tweakData.minimumValue doubleValue];
                }
                else {
                    self.stepper.minValue = [self.tweakData.currentValue doubleValue] / 10.0;
                }
                
                if(self.tweakData.maximumValue) {
                    self.stepper.maxValue = [self.tweakData.maximumValue doubleValue];
                }
                else {
                    self.stepper.maxValue = [self.tweakData.currentValue doubleValue] * 10.0;
                }
                
                if(self.tweakData.stepValue) {
                    self.stepper.increment = [self.tweakData.stepValue floatValue];
                }
                else {
                    self.stepper.increment = fminf(1.0, (self.stepper.maxValue - self.stepper.minValue) / 100.0);
                }
                break;
                
            case FBTweakDataTypeString:
                [self.textField setHidden:NO];
                [self.stepper setHidden:YES];
                [self.checkButton setHidden:YES];
                [self.actionButton setHidden:YES];
                break;
                
            case FBTweakDataTypeAction:
                [self.textField setHidden:YES];
                [self.stepper setHidden:YES];
                [self.checkButton setHidden:YES];
                [self.actionButton setHidden:NO];
                break;
                
            case FBTweakDataTypeNone:
            default:
                break;
        }
    }
    
    [self _updateValue:_tweakData.currentValue primary:YES write:NO];
}

- (IBAction)_switchChanged:(NSButton *)button {
    [self _updateValue:self.checkButton.state == NSOnState ? @(YES) : @(NO) primary:NO write:YES];
}

- (IBAction)_stepperChanged:(NSStepper *)stepper {
    if(self.tweakData.type == FBTweakDataTypeInteger) {
        [self _updateValue:@(stepper.integerValue) primary:NO write:YES];
    }
    else {
        [self _updateValue:@(stepper.doubleValue) primary:NO write:YES];
    }
}

- (IBAction)_actionPressed:(NSButton *)button {
    if([self.delegate respondsToSelector:@selector(tweakAction:)]) {
        [self.delegate tweakAction:self.tweakData];
    }
}

- (void)_updateValue:(id)value primary:(BOOL)primary write:(BOOL)write {
    if(write) {
        self.tweakData.currentValue = value;
        if([self.delegate respondsToSelector:@selector(tweakDidChange:)]) {
            [self.delegate tweakDidChange:self.tweakData];
        }
    }
    
    switch(self.tweakData.type) {
        case FBTweakDataTypeBoolean:
            if(primary) {
                [self.checkButton setState:[value boolValue] ? NSOnState : NSOffState];
            }
            break;
            
        case FBTweakDataTypeInteger:
            if(primary) {
                [self.stepper setIntegerValue:[value integerValue]];
            }
            
            [self.textField setStringValue:[value stringValue]];
            break;
            
        case FBTweakDataTypeReal: {
            if(primary) {
                [self.stepper setDoubleValue:[value doubleValue]];
            }
            
            double exp = log10(self.stepper.increment);
            long precision = exp < 0 ? ceilf(fabs(exp)) : 0;

            if(self.tweakData.precisionValue) {
             precision = [[self.tweakData precisionValue] longValue];
            }

            NSString *format = [NSString stringWithFormat:@"%%.%ldf", precision];
            [self.textField setStringValue:[NSString stringWithFormat:format, [value doubleValue]]];
            break;
        }
            
        case FBTweakDataTypeString:
            if(primary) {
                [self.textField setStringValue:value];
            }
            break;
            
        case FBTweakDataTypeAction:
        case FBTweakDataTypeNone:
        default:
            break;
    }
}

#pragma mark - NSTextFieldDelegate

- (void)controlTextDidEndEditing:(NSNotification *)notification {
    switch(self.tweakData.type) {
        case FBTweakDataTypeInteger:
            [self _updateValue:@([self.textField integerValue]) primary:NO write:YES];
            break;
            
        case FBTweakDataTypeReal:
            [self _updateValue:@([self.textField doubleValue]) primary:NO write:YES];
            break;
            
        case FBTweakDataTypeString:
            [self _updateValue:self.textField.stringValue primary:NO write:YES];
            break;
            
        case FBTweakDataTypeAction:
        case FBTweakDataTypeBoolean:
        case FBTweakDataTypeNone:
        default:
            NSAssert(NO, @"unexpected type");
            break;
    }
}
@end
