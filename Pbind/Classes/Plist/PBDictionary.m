//
//  PBDictionary.m
//  Pbind <https://github.com/wequick/Pbind>
//
//  Created by galen on 15/5/27.
//  Copyright (c) 2015-present, Wequick.net. All rights reserved.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "PBDictionary.h"

@implementation PBDictionary

@synthesize dictionary = _dictionary;

+ (instancetype)dictionaryWithCapacity:(NSUInteger)capacity
{
    PBDictionary *dictionary = [[PBDictionary alloc] init];
    dictionary->_dictionary = [NSMutableDictionary dictionaryWithCapacity:capacity];
    return dictionary;
}

+ (instancetype)dictionaryWithDictionary:(NSDictionary *)dict
{
    PBDictionary *dictionary = [[PBDictionary alloc] initWithDictionary:dict];
    return dictionary;
}

- (instancetype)init
{
    if (self = [super init]) {
        _dictionary = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict
{
    if (self = [super init]) {
        _dictionary = [NSMutableDictionary dictionaryWithDictionary:dict];
    }
    return self;
}

- (void)setValue:(id)value forKeyPath:(NSString *)keyPath
{
    [self willChangeValueForKey:keyPath];
    [_dictionary setValue:value forKeyPath:keyPath];
    [self didChangeValueForKey:keyPath];
}

- (void)setValue:(id)value forKey:(NSString *)key
{
    [self willChangeValueForKey:key];
    [_dictionary setValue:value forKey:key];
    [self didChangeValueForKey:key];
}

- (id)valueForKey:(NSString *)key
{
    return [_dictionary valueForKey:key];
}

- (id)valueForKeyPath:(NSString *)keyPath
{
    return [_dictionary valueForKeyPath:keyPath];
}

- (id)objectForKey:(id)key
{
    return [_dictionary objectForKeyedSubscript:key];
}

- (void)setObject:(id)obj forKey:(id<NSCopying>)key
{
    id oldObj = [_dictionary objectForKey:key];
    if (obj == nil) {
        if (oldObj == nil) {
            return;
        }
    } else if ([obj isEqual:oldObj]) {
        return;
    }
    
    NSString *keyPath = (id) key;
    [self willChangeValueForKey:keyPath];
    [_dictionary setObject:obj forKeyedSubscript:key];
    [self didChangeValueForKey:keyPath];
}

- (id)objectForKeyedSubscript:(id)key
{
    return [self objectForKey:key];
}

- (void)setObject:(id)obj forKeyedSubscript:(id<NSCopying>)key
{
    [self setObject:obj forKey:key];
}

- (void)removeObjectForKey:(id)aKey
{
    if ([_dictionary objectForKey:aKey] == nil) {
        return;
    }
    
    [self willChangeValueForKey:aKey];
    [_dictionary removeObjectForKey:aKey];
    [self didChangeValueForKey:aKey];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id  _Nullable __unsafe_unretained [])buffer count:(NSUInteger)len {
    return [_dictionary countByEnumeratingWithState:state objects:buffer count:len];
}

- (void)willChangeValueForKey:(NSString *)key
{
    if (self.owner != nil) {
        [self.owner willChangeValueForKey:key];
        return;
    }
    [super willChangeValueForKey:key];
}

- (void)didChangeValueForKey:(NSString *)key
{
    if (self.owner != nil) {
        [self.owner didChangeValueForKey:key];
        return;
    }
    [super didChangeValueForKey:key];
}

- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath context:(void *)context
{
    [super removeObserver:observer forKeyPath:keyPath context:context];
}

- (NSString *)description {
    return [_dictionary description];
}

- (NSUInteger)count {
    return [_dictionary count];
}

#pragma mark - Copy

- (id)copyWithZone:(nullable NSZone *)zone {
    NSMutableDictionary *dict = [_dictionary mutableCopyWithZone:zone];
    PBDictionary *copy = [[PBDictionary allocWithZone:zone] initWithDictionary:dict];
    return copy;
}

@end
