//
//  LSDatePicker.m
//  Less
//
//  Created by galen on 15/2/28.
//  Copyright (c) 2015年 galen. All rights reserved.
//

#import "LSDatePicker.h"

@implementation LSDatePicker

DEF_SINGLETON(sharedDatePicker)

- (void)setDatePickerMode:(UIDatePickerMode)datePickerMode
{
    _lsFlags.pickerMode = datePickerMode;
    if ((int)datePickerMode == LSDatePickerModeMonth) {
        datePickerMode = 4269; // :( After many works, I found all the task to do is simply to set this value :)
    }
    [super setDatePickerMode:datePickerMode];
}

- (UIDatePickerMode)datePickerMode
{
    return _lsFlags.pickerMode;
}

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    if (!self.enabled) {
        return NO;
    }
    return [super beginTrackingWithTouch:touch withEvent:event];
}

- (NSString *)textForValue:(id)value
{
    NSString *text = nil;
    if (value == nil) {
        return nil;
    }
    if ([value isKindOfClass:[NSNumber class]]) {
        NSTimeInterval interval = [value longLongValue];
        if (interval == 0) {
            return nil;
        } else if (interval > 0) {
            value = [NSDate dateWithTimeIntervalSince1970:interval];
        }
    } else if (![value isKindOfClass:[NSDate class]]) {
        return nil;
    }
    
    switch ((int)self.datePickerMode) {
        case UIDatePickerModeDate:
            text = [NSDateFormatter localizedStringFromDate:value dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterNoStyle];
            break;
        case UIDatePickerModeTime:
            text = [NSDateFormatter localizedStringFromDate:value dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterShortStyle];
            break;
        case UIDatePickerModeDateAndTime:
            text = [NSDateFormatter localizedStringFromDate:value dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterShortStyle];
            break;
        case LSDatePickerModeMonth:
        {
            NSString *formatString = [NSDateFormatter dateFormatFromTemplate:@"MMMy" options:0 locale:[NSLocale currentLocale]];
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateFormat:formatString];
            text = [dateFormatter stringFromDate:value];
            break;
        }
        default:
            break;
    }
    return text;
}

@end
