//
//  PBRowActionMapper.h
//  Pbind <https://github.com/wequick/Pbind>
//
//  Created by Galen Lin on 26/12/2016.
//  Copyright (c) 2015-present, Wequick.net. All rights reserved.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <UIKit/UIKit.h>
#import "PBActionMapper.h"

@interface PBRowActionMapper : PBActionMapper

@property (nonatomic, assign) UITableViewRowActionStyle style;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) UIColor *backgroundColor;

@end
