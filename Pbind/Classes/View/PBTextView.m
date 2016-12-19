//
//  PBTextView.m
//  Pbind
//
//  Created by galen on 15/4/12.
//  Copyright (c) 2015年 galen. All rights reserved.
//

#import "PBTextView.h"
#import "NSString+PBInput.h"

@implementation PBTextView

@synthesize type, name, value, required, requiredTips;
@synthesize maxlength, maxchars, pattern, validators;

- (id)init {
    if (self = [super init]) {
        [self config];
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self config];
}

- (void)config {
    self.delegate = self;
}

- (id)value {
    return self.text;
}

- (void)setValue:(id)aValue {
    if ([aValue isEqual:[NSNull null]]) {
        self.text = nil;
    } else {
        self.text = aValue;
    }
}

- (void)reset {
    self.text = nil;
}

- (void)setText:(NSString *)text {
    [super setText:text];
    if (![text isEqual:[NSNull null]] && text.length != 0) {
        if (!_placeholderLabel.hidden) {
            _placeholderLabel.hidden = YES;
        }
    } else {
        _placeholderLabel.hidden = NO;
    }
}

- (void)initPlaceholder {
    if (_placeholderLabel == nil) {
        _placeholderLabel = [[UILabel alloc] init];
        [_placeholderLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
        [_placeholderLabel setBackgroundColor:[UIColor clearColor]];
//        [_placeholderLabel setFont:self.font];
        [_placeholderLabel setTextColor:[UIColor lightGrayColor]];
        [_placeholderLabel setNumberOfLines:0];
        [_placeholderLabel setTextAlignment:NSTextAlignmentLeft];
        [self addSubview:_placeholderLabel];
        
//        CGRect labelRect = self.bounds;
//        UIView *placeholderWrapperView = [[UIView alloc] initWithFrame:labelRect];
//        [placeholderWrapperView setUserInteractionEnabled:NO];
//        [placeholderWrapperView setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight];
//        [self addSubview:placeholderWrapperView];
//        
//        CGRect caretRect = [self caretRectForPosition:self.beginningOfDocument];
//        labelRect.origin = caretRect.origin;
//        labelRect.size.width -= labelRect.origin.x * 2;
//        _placeholderLabel = [[UILabel alloc] initWithFrame:labelRect];
//        [_placeholderLabel setBackgroundColor:[UIColor clearColor]];
//        [_placeholderLabel setFont:self.font];
//        [_placeholderLabel setTextColor:[UIColor lightGrayColor]];
//        [_placeholderLabel setNumberOfLines:0];
//        [_placeholderLabel setTextAlignment:NSTextAlignmentLeft];
//        [placeholderWrapperView addSubview:_placeholderLabel];
//        // Autolayout
//        [_placeholderLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
//        NSArray *formats = @[@"H:|-(x)-[pl]-(x)-|", @"V:|-(y)-[pl]"];
//        NSDictionary *views = @{@"pl":_placeholderLabel};
//        NSDictionary *metrics = @{@"x":@(labelRect.origin.x), @"y":@(labelRect.origin.y), @"w":@(labelRect.size.width)};
//        [formats enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
//            [placeholderWrapperView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:obj options:0 metrics:metrics views:views]];
//        }];
    }
}

- (void)setPlaceholder:(NSString *)placeholder {
    [self initPlaceholder];
    [_placeholderLabel setText:placeholder];
    _placeholder = placeholder;
}

- (void)setPlaceholderColor:(UIColor *)placeholderColor {
    [self initPlaceholder];
    [_placeholderLabel setTextColor:placeholderColor];
    _placeholderColor = placeholderColor;
}

- (void)updateConstraints {
    [super updateConstraints];
    
    if (_placeholderLabel != nil) {
        CGRect caretRect = [self caretRectForPosition:self.beginningOfDocument];
        _placeholderLabel.font = self.font;
        [self addConstraint:[NSLayoutConstraint constraintWithItem:_placeholderLabel attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeLeft multiplier:1 constant:caretRect.origin.x]];
        [self addConstraint:[NSLayoutConstraint constraintWithItem:_placeholderLabel attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeRight multiplier:1 constant:caretRect.origin.x]];
        [self addConstraint:[NSLayoutConstraint constraintWithItem:_placeholderLabel attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTop multiplier:1 constant:caretRect.origin.y]];
    }
}

- (void)setContentSize:(CGSize)contentSize {
    [super setContentSize:contentSize];
    NSLog(@"size: %.2f, %.2f", contentSize.width, contentSize.height);
}

- (CGSize)sizeThatFits:(CGSize)size {
    
    CGSize newSize = [super sizeThatFits:size];
    NSLog(@"newSize: %.2f, %.2f", newSize.width, newSize.height);
    return newSize;
}

#pragma mark - UITextViewDelegate

- (void)textViewDidBeginEditing:(UITextView *)textView {
    _originalText = textView.text;
}

- (void)textViewDidChange:(UITextView *)textView {
    if (self.text.length == 0) {
        [_placeholderLabel setHidden:NO];
    } else {
        [_placeholderLabel setHidden:YES];
    }
    // Re-check text length for auto-correction inputs (Chinese, etc.)
    if (maxchars != 0 && [textView.text charaterLength] > maxchars) {
        textView.text = _originalText;
        return;
    }
    if (maxlength != 0 && [textView.text length] > maxlength) {
        textView.text = _originalText;
        return;
    }
    _originalText = textView.text;
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)string {
    if ([string isEqualToString:@""]) { // Backspace
        return YES;
    }
    
//    NSLog(@"--- %i-%i", (int)[textView.text length], (int)maxlength);
    if (maxchars != 0 && strlen([textView.text cStringUsingEncoding:NSUTF8StringEncoding]) == maxchars) {
        return NO;
    }
    if (maxlength != 0 && [textView.text length] == maxlength) {
        return NO;
    }
    
    if (pattern != nil) {
        NSPredicate *test = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", pattern];
        if (![test evaluateWithObject:string]){
            return NO;
        }
    }
    
    return YES;
}

@end
