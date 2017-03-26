//
//  PBSectionMapper.m
//  Pbind <https://github.com/wequick/Pbind>
//
//  Created by galen on 15/2/17.
//  Copyright (c) 2015-present, Wequick.net. All rights reserved.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "PBSectionMapper.h"
#import "PBRowMapper.h"
#import "Pbind+API.h"

@interface PBRowMapper (Private)

- (void)initDefaultViewClass;

@end

@implementation PBSectionMapper

- (void)initDefaultViewClass {
    if ([self.owner isKindOfClass:[UICollectionView class]]) {
        self.clazz = @"UICollectionReusableView";
    } else {
        self.clazz = @"UIView";
    }
}

- (NSInteger)rowCount {
    NSInteger rowCount = 0;
    if (self.row != nil) {
        rowCount = [self.data count];
        if (rowCount == 0 && self.emptyRow != nil) {
            rowCount = 1;
        }
    } else {
        rowCount = [self.rows count];
    }
    return rowCount;
}

- (void)setItem:(id)item {
    self.row = item;
}

- (id)item {
    return self.row;
}

- (void)setItems:(NSArray *)items {
    self.rows = items;
}

- (NSArray *)items {
    return self.rows;
}

@end
