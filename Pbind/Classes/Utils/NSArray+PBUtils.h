//
//  NSArray+PBUtils.h
//  Pbind
//
//  Created by galen on 15/3/1.
//  Copyright (c) 2015年 galen. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSArray (PBUtils)

- (NSArray *)arrayByReplacingObjectsWithBlock:(id (^)(NSInteger index, id object))block;
- (NSArray *)arrayByReplacingDictionariesWithClass:(Class)aClass;

@end
