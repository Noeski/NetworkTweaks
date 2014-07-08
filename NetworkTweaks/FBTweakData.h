//
//  FBTweakData.h
//  NetworkTweaks
//
//  Created by Noah Hilt on 7/7/14.
//  Copyright (c) 2014 Noah Hilt. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef id FBTweakDataValue;

typedef enum {
    FBTweakDataTypeNone,
    FBTweakDataTypeBoolean,
    FBTweakDataTypeInteger,
    FBTweakDataTypeReal,
    FBTweakDataTypeString,
    FBTweakDataTypeAction
} FBTweakDataType;

@interface FBTweakCategory : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) NSArray *collections;

- (id)initWithDictionary:(NSDictionary *)dictionary;
@end

@interface FBTweakCollection : NSObject
@property (nonatomic, weak) FBTweakCategory *category;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) NSArray *tweaks;

- (id)initWithDictionary:(NSDictionary *)dictionary;
@end

@interface FBTweakData : NSObject
@property (nonatomic, weak) FBTweakCollection *collection;
@property (nonatomic, readonly) FBTweakDataType type;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) FBTweakDataValue currentValue;
@property (nonatomic, strong) FBTweakDataValue minimumValue;
@property (nonatomic, strong) FBTweakDataValue maximumValue;
@property (nonatomic, strong) FBTweakDataValue stepValue;
@property (nonatomic, strong) FBTweakDataValue precisionValue;

- (id)initWithDictionary:(NSDictionary *)dictionary;
@end


