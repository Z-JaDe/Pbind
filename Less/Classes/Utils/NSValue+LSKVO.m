//
//  NSValue+LSKVO.m
//  Less
//
//  Created by Galen Lin on 16/9/5.
//  Copyright © 2016年 galen. All rights reserved.
//

#import "NSValue+LSKVO.h"
#import <UIKit/UIKit.h>

@implementation NSValue (LSKVO)

- (id)valueForKeyPath:(NSString *)keyPath {
    if ([keyPath isEqualToString:@"size"]) {
        return [NSValue valueWithCGSize:[self CGRectValue].size];
    } else if ([keyPath isEqualToString:@"height"]) {
        return [NSNumber numberWithFloat:[self CGSizeValue].height];
    } else if ([keyPath isEqualToString:@"width"]) {
        return [NSNumber numberWithFloat:[self CGSizeValue].width];
    }
    return [super valueForKeyPath:keyPath];
}

@end
