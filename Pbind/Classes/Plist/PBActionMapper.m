//
//  PBActionMapper.m
//  Pbind <https://github.com/wequick/Pbind>
//
//  Created by Galen Lin on 2016/12/15.
//  Copyright (c) 2015-present, Wequick.net. All rights reserved.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "PBActionMapper.h"

@implementation PBActionMapper

- (void)setPropertiesWithDictionary:(NSDictionary *)dictionary {
    self.type = dictionary[@"type"];
    
    NSMutableDictionary *properties = [NSMutableDictionary dictionaryWithDictionary:dictionary];
    _viewProperties = [PBMapperProperties propertiesWithDictionary:properties];
}

@end
