//
//  LSArray.m
//  Less
//
//  Created by Galen Lin on 16/9/5.
//  Copyright © 2016年 galen. All rights reserved.
//

#import "LSArray.h"

@implementation LSArray

@synthesize array = _array;

+ (instancetype)arrayWithCapacity:(NSUInteger)capacity {
    LSArray *arr = [[self alloc] init];
    arr->_array = [NSMutableArray arrayWithCapacity:capacity];
    return arr;
}

+ (instancetype)arrayWithArray:(NSArray *)array {
    LSArray *arr = [[self alloc] initWithArray:array];
    return arr;
}

- (id)initWithArray:(NSArray *)array {
    if (self = [super init]) {
        _array = [NSMutableArray arrayWithArray:array];
    }
    return self;
}

- (id)objectAtIndexedSubscript:(NSUInteger)idx {
    return [_array objectAtIndexedSubscript:idx];
}

- (void)setObject:(id)obj atIndexedSubscript:(NSUInteger)idx {
    [_array setObject:obj atIndexedSubscript:idx];
}

- (void)addObject:(id)anObject {
    [_array addObject:anObject];
}

- (NSUInteger)count {
    return [_array count];
}

- (NSArray *)list {
    id list = [_array objectAtIndex:_listElementIndex];
    if ([list isEqual:[NSNull null]]) {
        return nil;
    }
    return list;
}

- (NSString *)description {
    return [_array description];
}

#pragma mark - Copy

- (id)copyWithZone:(nullable NSZone *)zone {
    NSMutableArray *array = [_array mutableCopyWithZone:zone];
    LSArray *copy = [[LSArray allocWithZone:zone] initWithArray:array];
    return copy;
}

@end
