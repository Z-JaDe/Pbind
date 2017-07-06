//
//  PBTextView.m
//  Pbind <https://github.com/wequick/Pbind>
//
//  Created by galen on 15/4/12.
//  Copyright (c) 2015-present, Wequick.net. All rights reserved.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "PBTextView.h"
#import "NSString+PBInput.h"

@interface PBTextLink ()

#pragma mark - Caching
///=============================================================================
/// @name Caching
///=============================================================================

@property (nonatomic, strong) NSRegularExpression *regexp;

@property (nonatomic, strong) NSArray<NSValue *> *textRanges;

@property (nonatomic, strong) NSArray<NSValue *> *valueRanges;

@property (nonatomic, assign) BOOL calculatedRegexp;
@property (nonatomic, assign) NSRange deletingRange;

@end

@implementation PBTextLink

- (NSRegularExpression *)regexp {
    if (_regexp == nil) {
        if (_calculatedRegexp) {
            return nil;
        }
        
        NSError *error = nil;
        _regexp = [NSRegularExpression regularExpressionWithPattern:_pattern options:NSRegularExpressionCaseInsensitive error:&error];
        if (_regexp == nil) {
            NSLog(@"Pbind: Failed to parse link pattern '%@'. (error: %@)", _pattern, error);
        }
        _calculatedRegexp = YES;
    }
    return _regexp;
}

@end

@implementation PBTextView

@synthesize type, name, value, required, requiredTips;
@synthesize maxlength, maxchars, pattern, validators;
@synthesize acceptsClearOnAccessory;
@synthesize errorRow;

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
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
    self.type = @"text";
    self.font = [PBInput new].font;
    self.textContainerInset = UIEdgeInsetsMake(0, 0, 0, 0);
    self.acceptsClearOnAccessory = YES;
    _pbFlags.needsUpdateValue = YES;
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (_pbFlags.lazyPostChangedNotification && self.window) {
        [[NSNotificationCenter defaultCenter] postNotificationName:UITextViewTextDidChangeNotification object:self];
        _pbFlags.lazyPostChangedNotification = 0;
    }
}

- (void)setValue:(id)aValue {
    if ([aValue isEqual:[NSNull null]]) {
        aValue = nil;
    }
    
    _originalValue = value;
    
    if (![self validateText:aValue]) {
        [self updateTextWithValue:_originalValue];
        return;
    }
    
    if (![self updateTextWithValue:aValue]) {
        return;
    }
    
    value = aValue;
}

- (void)insertValue:(NSString *)aValue {
    if (self.markedTextRange != nil) {
        return;
    }
    
    if (value == nil) {
        [self setValue:aValue];
        return;
    }
    
    [self replaceValueInTextRange:self.selectedRange withString:aValue textChanged:NO];
}

- (void)reset {
    self.text = nil;
    [super setAttributedText:nil];
}

- (BOOL)isEmpty {
    return value == nil || [value isEqual:[NSNull null]] || [value length] == 0;
}

- (void)setText:(NSString *)text {
    [super setText:text];
    [self onTextChanged:text];
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
    [super setAttributedText:attributedText];
    [self onTextChanged:attributedText];
}

- (void)onTextChanged:(NSString *)text {
    [self updateValueWithText:text notifyChanged:NO];
    if (self.window == nil) {
        _pbFlags.lazyPostChangedNotification = 1;
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:UITextViewTextDidChangeNotification object:self];
    }
    
    if (![text isEqual:[NSNull null]] && text.length != 0) {
        if (!_placeholderLabel.hidden) {
            _placeholderLabel.hidden = YES;
        }
    } else {
        _placeholderLabel.hidden = NO;
    }
}

- (void)updateValueWithText:(NSString *)text notifyChanged:(BOOL)notifyChanges {
    if (self.links != nil) {
        return;
    }
    
    if (notifyChanges) {
        self.value = text;
    } else {
        value = text;
    }
}

- (void)initPlaceholder {
    if (_placeholderLabel == nil) {
        PBInput *tempInput = [PBInput new];
        tempInput.placeholder = @"temp";
        UIColor *placeholderColor = tempInput.placeholderColor;
        
        _placeholderLabel = [[UILabel alloc] init];
        [_placeholderLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
        [_placeholderLabel setBackgroundColor:[UIColor clearColor]];
        [_placeholderLabel setFont:self.font];
        [_placeholderLabel setTextColor:placeholderColor];
        [_placeholderLabel setNumberOfLines:0];
        [_placeholderLabel setTextAlignment:NSTextAlignmentLeft];
        [self addSubview:_placeholderLabel];
        
        [self addConstraint:[NSLayoutConstraint constraintWithItem:_placeholderLabel attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
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

- (void)setFont:(UIFont *)font {
    [super setFont:font];
    _originalFont = font;
    if (_placeholderLabel != nil) {
        [_placeholderLabel setFont:font];
    }
}

- (void)updateConstraints {
    // Update placeholder label left and right margin by caret rect.
    if (_placeholderLabel != nil) {
        CGRect caretRect = [self caretRectForPosition:self.beginningOfDocument];
        if (_placeholderLeftMarginConstraint == nil) {
            _placeholderLeftMarginConstraint = [NSLayoutConstraint constraintWithItem:_placeholderLabel attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeLeft multiplier:1 constant:caretRect.origin.x];
            [self addConstraint:_placeholderLeftMarginConstraint];
        } else {
            _placeholderLeftMarginConstraint.constant = caretRect.origin.x;
        }
        
        if (_placeholderRightMarginConstraint == nil) {
            _placeholderRightMarginConstraint = [NSLayoutConstraint constraintWithItem:_placeholderLabel attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeRight multiplier:1 constant:caretRect.origin.x];
        } else {
            _placeholderRightMarginConstraint.constant = caretRect.origin.x;
        }
    }
    
    // Update height
    CGSize size = [self sizeThatFits:CGSizeMake(self.bounds.size.width, FLT_MAX)];
    if (_heightConstraint == nil) {
        _heightConstraint = [NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:size.height];
        [self addConstraint:_heightConstraint];
    } else {
        _heightConstraint.constant = size.height;
    }
    
    [super updateConstraints];
}

#pragma mark - UITextViewDelegate

- (void)textViewDidBeginEditing:(UITextView *)textView {
    [self saveOriginalText];
}

- (void)textViewDidEndEditing:(UITextView *)textView {
    if (_deletingLink == nil) {
        return;
    }
    
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithAttributedString:self.attributedText];
    [attributedText setAttributes:[self mergedAttributes:_deletingLink.attributes] range:_deletingLink.deletingRange];
    self.attributedText = attributedText;
    _deletingLink = nil;
}

- (BOOL)validateText:(NSString *)text {
    // Re-check text length for auto-correction inputs (Chinese, etc.)
    if (maxchars != 0 && [text charaterLength] > maxchars) {
        return NO;
    }
    if (maxlength != 0 && [text length] > maxlength) {
        return NO;
    }
    return YES;
}

- (void)saveOriginalText {
    _originalText = self.attributedText ?: self.text;
}

- (void)restoreOriginalText {
    if ([_originalText isKindOfClass:[NSAttributedString class]]) {
        self.attributedText = _originalText;
    } else {
        self.text = _originalText;
    }
}

- (void)textViewDidChange:(UITextView *)textView {
    if (self.text.length == 0) {
        [_placeholderLabel setHidden:NO];
    } else {
        [_placeholderLabel setHidden:YES];
    }
    
    if (![self validateText:textView.text]) {
        [self restoreOriginalText];
        [self updateValueWithText:_originalText notifyChanged:YES];
        return;
    }
    
    if (self.links != nil) {
        if (textView.markedTextRange == nil) { // End inputing
            if (!_pbFlags.needsUpdateValue) {
                return;
            }
            
            NSString *replacingString = _replacingString;
            NSRange replacingRange = _replacingRange;
            if (_previousMarkedTextRange != nil) {
                // Autocomplete
                UITextRange *replacingTextRange = _previousMarkedTextRange;
                if (replacingString == nil) {
                    replacingRange.location = [textView offsetFromPosition:textView.beginningOfDocument toPosition:replacingTextRange.start];
                    replacingRange.length = 0;
                }
                replacingString = [textView textInRange:replacingTextRange];
            }
            if (replacingString == nil) {
                const char *str2 = [textView.text UTF8String];
                if (*str2 == '\0') {
                    [self saveOriginalText];
                    value = nil;
                    return;
                }
                
                if ([_originalText isKindOfClass:[NSAttributedString class]]) {
                    [self setValue:_originalValue];
                    return;
                }
                
                const char *str1 = [_originalText UTF8String];
                char *p1 = (char *)str1;
                char *p2 = (char *)str2;
                int pos = 0;
                while (*p1++ == *p2++) {
                    pos++;
                    if (*p1 == '\0' || *p2 == '\0') {
                        break;
                    }
                }
                
                replacingRange = NSMakeRange(pos, strlen(str1) - pos);
                replacingString = [[NSString alloc] initWithUTF8String:p2-1];
            } else if (replacingRange.location == 0 && replacingRange.length == 0 && replacingString.length == 0) {
                replacingString = self.text;
            }
            [self replaceValueInTextRange:replacingRange withString:replacingString textChanged:YES];
//            [self updateValueAfterChangeCharactersInRange:replacingRange replacementString:replacingString];
            _replacingString = nil;
            _previousMarkedTextRange = textView.markedTextRange;
        } else {
            _previousMarkedTextRange = textView.markedTextRange;
            NSInteger len1 = _originalText.length;
            NSInteger len2 = self.text.length;
            if (len2 > len1) {
                NSMutableString *previewValue = value ? [NSMutableString stringWithString:value] : [NSMutableString string];
                [previewValue appendString:[self.text substringFromIndex:len1]];
                if (![self validateText:previewValue]) {
                    [self restoreOriginalText];
                    [self updateValueWithText:_originalText notifyChanged:YES];
                    return;
                }
            }
        }
    }
    
    [self saveOriginalText];
    [self updateValueWithText:_originalText notifyChanged:YES];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)string {
    BOOL shouldChange = YES;
    do {
        if ([string isEqualToString:@""]) { // Backspace
            shouldChange = [self canDeleteTextInRange:range];
            break;
        }
        
        if (maxchars != 0 && strlen([textView.text charaterLength]) == maxchars) {
            shouldChange = NO;
            break;
        }
        if (maxlength != 0 && [textView.text length] == maxlength) {
            shouldChange = NO;
            break;
        }
        
        if (pattern != nil) {
            NSPredicate *test = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", pattern];
            if (![test evaluateWithObject:string]){
                shouldChange = NO;
                break;
            }
        }
    } while (false);
    
    if (shouldChange) {
        if (_replacingString == nil) { // Save to format text at `textFieldDidChange:'
            _replacingRange = range;
            _replacingString = string;
        }
    }
    
    return shouldChange;
}

- (BOOL)canDeleteTextInRange:(NSRange)range {
    if (self.links == nil) {
        return YES;
    }
    
    if (range.length != 1) {
        return YES;
    }
    
    if (_deletingLink != nil) {
        // User had confirmed yet, delete it
        _deletingLink = nil;
        return YES;
    }
    
    // We take a #link# as a whole part which can not be delete only while it had been select
    PBTextLink *deletingLink = nil;
    for (PBTextLink *link in self.links) {
        if (link.deletingAttributes == nil) {
            // If missing the style of deleting, directly delete it
            continue;
        }
        
        for (NSValue *wrapper in link.textRanges) {
            NSRange textRange = [wrapper rangeValue];
            if (textRange.location + textRange.length == range.location + 1) {
                link.deletingRange = textRange;
                deletingLink = link;
                break;
            }
        }
        if (deletingLink != nil) {
            break;
        }
    }
    
    if (deletingLink == nil) {
        return YES;
    }
    
    // If the #link# has been selected then it can be delete
    NSRange deletingRange = deletingLink.deletingRange;
    NSRange selectedRange = self.selectedRange;
    if (NSEqualRanges(selectedRange, deletingRange)) {
        return YES;
    }
    
    // Select the #link# to give a chance for user to confirm
    UITextRange *bak = self.selectedTextRange;
    
    // Update the selection style
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithAttributedString:self.attributedText];
    [attributedText setAttributes:[self mergedAttributes:deletingLink.deletingAttributes] range:deletingRange];
    self.attributedText = attributedText;
    
    // TODO: Let the keyboard accessory view displays the auto-complection tips
//    UITextPosition *start = [self positionFromPosition:self.beginningOfDocument offset:deletingRange.location];
//    UITextPosition *end = [self positionFromPosition:start offset:deletingRange.length];
//    UITextRange *deletingTextRange = [self textRangeFromPosition:start toPosition:end];
//
//    [self.inputDelegate selectionWillChange:self];
//    self.selectedTextRange = deletingTextRange;
//    [self.inputDelegate selectionDidChange:self];
//    
    self.selectedTextRange = bak;
    
    // Mark confirmed
    _deletingLink = deletingLink;
    
    return NO;
}

- (void)textViewDidChangeSelection:(UITextView *)textView {
    if (self.links == nil) {
        return;
    }
    
    NSRange selectedRange = textView.selectedRange;
    for (PBTextLink *link in self.links) {
        for (NSValue *wrapper in link.textRanges) {
            NSRange textRange = [wrapper rangeValue];
            // We take a #link# as a whole part which can not put cursor in the middle of it.
            if (NSLocationInRange(selectedRange.location, textRange)) {
                if (selectedRange.length == 0) {
                    // move the cursor to the edge of the #link#
                    NSInteger edgeLocation = textRange.location;
                    if (selectedRange.location >= textRange.location + textRange.length / 2) {
                        edgeLocation = MIN(textRange.location + textRange.length, textView.text.length);
                    }
                    if (selectedRange.location != edgeLocation) {
                        selectedRange.location = edgeLocation;
                        textView.selectedRange = selectedRange;
                    }
                } else {
                    // select the whole #link#
                    BOOL changed = NO;
                    NSUInteger selectedRangeRight = NSMaxRange(selectedRange);
                    if (selectedRange.location > textRange.location) {
                        selectedRange.location = textRange.location;
                        selectedRange.length = selectedRangeRight - selectedRange.location;
                        changed = YES;
                    }
                    NSUInteger textRangeRight = NSMaxRange(textRange);
                    if (selectedRangeRight < textRangeRight) {
                        selectedRange.length = textRangeRight - selectedRange.location;
                        changed = YES;
                    }
                    if (changed) {
                        textView.selectedRange = selectedRange;
                    }
                }
                return;
            }
        }
    }
}

#pragma mark - User interaction

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];
    [self endEditing:YES];
}

#pragma mark - AutoResizing

- (CGSize)systemLayoutSizeFittingSize:(CGSize)targetSize {
    CGSize size;
    if (self.minHeight > 0) {
        if (self.translatesAutoresizingMaskIntoConstraints) {
            size.width = self.frame.size.width;
            size.height = CGFLOAT_MAX;
            size.height = [self sizeThatFits:size].height;
            size.height = MAX(size.height, self.minHeight);
        } else {
            BOOL scrollEnabled = self.scrollEnabled;
            self.scrollEnabled = NO;
            size = [super systemLayoutSizeFittingSize:targetSize];
            size.height = MAX(size.height, self.minHeight);
            self.scrollEnabled = scrollEnabled;
        }
    } else {
        if (self.translatesAutoresizingMaskIntoConstraints) {
            size.width = self.frame.size.width;
            size.height = CGFLOAT_MAX;
            size.height = [self sizeThatFits:size].height;
        } else {
            size = [super systemLayoutSizeFittingSize:targetSize];
        }
    }
    
    if (self.maxHeight > 0) {
        size.height = MIN(size.height, self.maxHeight);
    }
    return size;
}

#pragma mark - Helper

- (void)updateValueAfterChangeCharactersInRange:(NSRange)range replacementString:(nonnull NSString *)string {
    NSInteger length = range.length;
    NSInteger index = 0;
    
    NSMutableString *mutableValue;
    if (value == nil) {
        mutableValue = [NSMutableString string];
    } else {
        mutableValue = [NSMutableString stringWithString:value];
    }
    
    NSInteger offset = NSIntegerMax;
    NSInteger textLoc = range.location;
    NSInteger valueLoc = textLoc;
    NSRange deletingValueRange = NSMakeRange(0, 0);
    BOOL deleting = NO;
    BOOL empty = [string length] == 0;
    for (PBTextLink *link in _links) {
        for (NSInteger index = link.textRanges.count - 1; index >= 0; index--) {
            NSRange textRange = [link.textRanges[index] rangeValue];
            NSRange valueRange = [link.valueRanges[index] rangeValue];
            if (empty && range.location > textRange.location && NSMaxRange(range) <= NSMaxRange(textRange)) {
                deletingValueRange = valueRange;
                deleting = YES;
                break;
            }
            
            NSInteger temp = range.location - textRange.location - textRange.length;
            if (temp >= 0 && offset > temp) {
                offset = temp;
                valueLoc = valueRange.location + valueRange.length;
            }
        }
        
        if (deleting) break;
    }
    if (deleting) {
        [mutableValue deleteCharactersInRange:deletingValueRange];
        self.value = [mutableValue copy];
        return;
    }
    
    if (offset == NSIntegerMax) {
        offset = 0;
    }
    valueLoc += offset;
    
    if (length == 0) {
        if (valueLoc >= [mutableValue length]) {
            if (empty) {
                if (valueLoc == 0) {
                    // ??? If the text is empty -> Delete -> Append, go to this.
                    [mutableValue setString:self.text];
                    return;
                } else {
                    // Delete
                    NSRange deleteRange = NSMakeRange(valueLoc - 1, length + 1);
                    [mutableValue deleteCharactersInRange:deleteRange];
                }
            } else {
                // Append
                [mutableValue appendString:string];
            }
        } else {
            // Insert
            [mutableValue insertString:string atIndex:valueLoc];
        }
    } else {
        // Replace
        if (string == nil) {
            return;
        }
        NSRange replaceRange = NSMakeRange(valueLoc, length);
        if (mutableValue.length >= valueLoc) {
            [mutableValue replaceCharactersInRange:replaceRange withString:string];
        }
    }
    
    if (![self validateText:mutableValue]) {
        [self restoreOriginalText];
        [self updateValueWithText:_originalText notifyChanged:YES];
        return;
    }
    
    self.value = [mutableValue copy];
    if (!empty) {
        self.selectedRange = NSMakeRange(range.location - range.length + string.length, 0);
    }
}

- (BOOL)updateTextWithValue:(NSString *)aValue {
    if (aValue == nil || self.links == nil) {
        return YES;
    }
    
    NSString *text = aValue;
    NSInteger patternLoc = 0;
    NSInteger textLoc = 0;
    NSInteger offset = 0;
    for (PBTextLink *link in self.links) {
        NSRegularExpression *reg = link.regexp;
        if (reg == nil) {
            continue;
        }
        
        NSMutableArray *valueRanges = [NSMutableArray array];
        NSMutableArray *textRanges = [NSMutableArray array];
        NSArray<NSTextCheckingResult *> *results = [reg matchesInString:aValue options:0 range:NSMakeRange(0,  aValue.length)];
        for (NSTextCheckingResult *result in results) {
            NSRange range = result.range;
            [valueRanges addObject:[NSValue valueWithRange:range]];
            
            NSString *matchment = [aValue substringWithRange:range];
            NSString *replacement = [reg replacementStringForResult:result inString:aValue offset:0 template:link.text];
            
            range.location += offset;
            text = [text stringByReplacingCharactersInRange:range withString:replacement];
            offset += replacement.length - matchment.length;
            
            range.length = replacement.length;
            [textRanges addObject:[NSValue valueWithRange:range]];
        }
        
        link.valueRanges = valueRanges;
        link.textRanges = textRanges;
    }
    
    if (![self validateText:text]) {
        return NO;
    }
    
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:text];
    [attributedText addAttributes:@{NSFontAttributeName: _originalFont} range:NSMakeRange(0, text.length)];
    for (PBTextLink *link in self.links) {
        for (NSValue *value in link.textRanges) {
            [attributedText addAttributes:[self mergedAttributes:link.attributes] range:[value rangeValue]];
        }
    }
    
    _pbFlags.needsUpdateValue = NO;
    [self setAttributedText:attributedText];
    _pbFlags.needsUpdateValue = YES;
    
    _originalText = self.attributedText;
    return YES;
}

- (NSDictionary *)mergedAttributes:(NSDictionary *)attributes {
    if (attributes[NSFontAttributeName] == nil) {
        NSMutableDictionary *temp = [NSMutableDictionary dictionaryWithDictionary:attributes];
        temp[NSFontAttributeName] = _originalFont;
        return temp;
    }
    return attributes;
}

- (void)replaceValueInTextRange:(NSRange)range withString:(NSString *)string textChanged:(BOOL)textChanged {
    NSUInteger rangeLeft = range.location;
    NSUInteger rangeRight = NSMaxRange(range);
    __block NSInteger start = rangeLeft;
    __block NSInteger end = start + [value length] - [self.text length] + (textChanged ? string.length : 0);
    BOOL deleting = string.length == 0;
    [self enumerateLinkRanges:^(PBTextLink *link, NSRange textRange, NSRange valueRange, BOOL *stopped) {
        if (textRange.location < rangeLeft) {
            if (NSMaxRange(textRange) > rangeLeft) {
                start = valueRange.location;
                *stopped = YES;
                return;
            }
        } else {
            *stopped = YES;
            return;
        }
        start += valueRange.length - textRange.length;
    }];
    [self reverseEnumerateLinkRanges:^(PBTextLink *link, NSRange textRange, NSRange valueRange, BOOL *stopped) {
        NSUInteger right = NSMaxRange(textRange);
        if (right > rangeRight) {
            if (textRange.location < rangeLeft) {
                end = NSMaxRange(valueRange);
                *stopped = YES;
                return;
            }
        } else {
            *stopped = YES;
            return;
        }
        end -= valueRange.length - textRange.length;
    }];
    
    NSRange replacedValueRange = NSMakeRange(start, end - start);
    NSMutableString *mutableValue = value ? [NSMutableString stringWithString:value] : [NSMutableString string];
    [mutableValue replaceCharactersInRange:replacedValueRange withString:string];
    
    self.value = [mutableValue copy];
    
    __block NSInteger offset = 0;
    rangeRight = replacedValueRange.location + string.length;
    NSRange selectedRange = NSMakeRange(rangeRight, 0);
    [self enumerateLinkRanges:^(PBTextLink *link, NSRange textRange, NSRange valueRange, BOOL *stopped) {
        if (valueRange.location >= rangeRight) {
            *stopped = YES;
            return;
        }
        offset += valueRange.length - textRange.length;
    }];
    selectedRange.location -= offset;
    self.selectedRange = selectedRange;
}

- (void)enumerateLinkRanges:(void (^)(PBTextLink *link, NSRange textRange, NSRange valueRange, BOOL *stopped))operation {
    if (self.links == nil) {
        return;
    }
    
    BOOL stopped = NO;
    for (PBTextLink *link in self.links) {
        for (NSInteger index = 0; index < link.textRanges.count; index++) {
            NSRange textRange = [link.textRanges[index] rangeValue];
            NSRange valueRange = [link.valueRanges[index] rangeValue];
            operation(link, textRange, valueRange, &stopped);
            if (stopped) {
                break;
            }
        }
        if (stopped) {
            break;
        }
    }
}

- (void)reverseEnumerateLinkRanges:(void (^)(PBTextLink *link, NSRange textRange, NSRange valueRange, BOOL *stopped))operation {
    if (self.links == nil) {
        return;
    }
    
    BOOL stopped = NO;
    for (PBTextLink *link in self.links) {
        for (NSInteger index = link.textRanges.count - 1; index >= 0; index--) {
            NSRange textRange = [link.textRanges[index] rangeValue];
            NSRange valueRange = [link.valueRanges[index] rangeValue];
            operation(link, textRange, valueRange, &stopped);
            if (stopped) {
                break;
            }
        }
        if (stopped) {
            break;
        }
    }
}

@end
