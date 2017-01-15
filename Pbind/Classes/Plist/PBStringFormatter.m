//
//  PBVariableFormatter.m
//  Pbind <https://github.com/wequick/Pbind>
//
//  Created by galen on 15/4/28.
//  Copyright (c) 2015-present, Wequick.net. All rights reserved.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "PBStringFormatter.h"
#import "UIView+Pbind.h"

static NSMutableDictionary *kFormatters;

@implementation PBStringFormatter

+ (void)load
{
    // Date format
    [self registerTag:@"t" withFormatterer:^NSString *(NSString *format, id value) {
        NSDate *date = value;
        if ([value isKindOfClass:[NSNumber class]]) {
            date = [NSDate dateWithTimeIntervalSince1970:[value longLongValue]];
        }
        if (![date isKindOfClass:[NSDate class]]) {
            return @"<nil>";
        }
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:format];
        return [formatter stringFromDate:date];
    }];
    // Date template
    [self registerTag:@"T" withFormatterer:^NSString *(NSString *format, id value) {
        NSDate *date = value;
        if ([value isKindOfClass:[NSNumber class]]) {
            date = [NSDate dateWithTimeIntervalSince1970:[value longLongValue]];
        }
        if (![date isKindOfClass:[NSDate class]]) {
            return @"<nil>";
        }
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        NSString *dateFormat = [NSDateFormatter dateFormatFromTemplate:format options:0 locale:[NSLocale currentLocale]];
        [formatter setDateFormat:dateFormat];
        return [formatter stringFromDate:date];
    }];
}

+ (void)registerTag:(NSString *)tag withFormatterer:(NSString * (^)(NSString *format, id value))formatter
{
    if (kFormatters == nil) {
        kFormatters = [[NSMutableDictionary alloc] init];
    }
    [kFormatters setObject:formatter forKey:tag];
}

+ (NSArray *)allTags
{
    return [kFormatters allKeys];
}

+ (NSString * (^)(NSString *format, id value))formatterForTag:(NSString *)tag
{
    return [kFormatters objectForKey:tag];
}

@end
