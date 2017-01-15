//
//  PBTableViewCell.h
//  Pbind <https://github.com/wequick/Pbind>
//
//  Created by Galen Lin on 16/9/5.
//  Copyright (c) 2015-present, Wequick.net. All rights reserved.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <UIKit/UIKit.h>

@interface PBTableViewCell : UITableViewCell

@property (nonatomic, assign) CGSize imageSize; // Size of cell.imageView
@property (nonatomic, assign) UIEdgeInsets imageMargin; // Outside margins of cell.imageView

@end
