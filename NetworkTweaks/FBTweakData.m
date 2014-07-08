//
//  FBTweakData.m
//  NetworkTweaks
//
//  Created by Noah Hilt on 7/7/14.
//  Copyright (c) 2014 Noah Hilt. All rights reserved.
//

#import "FBTweakData.h"

@implementation FBTweakCategory

- (id)initWithDictionary:(NSDictionary *)dictionary {
    if(self = [super init]) {
        _name = [dictionary[@"name"] copy];
        
        NSArray *collections = dictionary[@"collections"];
        NSMutableArray *mutableCollections = [[NSMutableArray alloc] initWithCapacity:[collections count]];
        
        for(NSDictionary *collection in collections) {
            FBTweakCollection *tweakCollection = [[FBTweakCollection alloc] initWithDictionary:collection];
            tweakCollection.category = self;
            
            [mutableCollections addObject:tweakCollection];
        }
        
        _collections = mutableCollections;
    }
    
    return self;
    
}

@end

@implementation FBTweakCollection

- (id)initWithDictionary:(NSDictionary *)dictionary {
    if(self = [super init]) {
        _name = [dictionary[@"name"] copy];
        
        NSArray *tweaks = dictionary[@"tweaks"];
        NSMutableArray *mutableTweaks = [[NSMutableArray alloc] initWithCapacity:[tweaks count]];
        
        for(NSDictionary *tweak in tweaks) {
            FBTweakData *tweakData = [[FBTweakData alloc] initWithDictionary:tweak];
            tweakData.collection = self;
            
            [mutableTweaks addObject:tweakData];
        }
        
        _tweaks = mutableTweaks;
    }
    
    return self;
}

@end

@implementation FBTweakData

- (id)initWithDictionary:(NSDictionary *)dictionary {
    if(self = [super init]) {
        NSString *type = dictionary[@"type"];
        
        if([type isEqualToString:@"Boolean"]) {
            _type = FBTweakDataTypeBoolean;
        }
        else if([type isEqualToString:@"Integer"]) {
            _type = FBTweakDataTypeInteger;
        }
        else if([type isEqualToString:@"Real"]) {
            _type = FBTweakDataTypeReal;
        }
        else if([type isEqualToString:@"String"]) {
            _type = FBTweakDataTypeString;
        }
        else if([type isEqualToString:@"Action"]) {
            _type = FBTweakDataTypeAction;
        }
        else {
            _type = FBTweakDataTypeNone;
        }
        
        _identifier = [dictionary[@"identifier"] copy];
        _name = [dictionary[@"name"] copy];
        _currentValue = dictionary[@"value"];
        _minimumValue = dictionary[@"minimumValue"];
        _maximumValue = dictionary[@"maximumValue"];
        _stepValue = dictionary[@"stepValue"];
        _precisionValue = dictionary[@"precisionValue"];
    }
    
    return self;
}

@end