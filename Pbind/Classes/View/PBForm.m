//
//  PBForm.m
//  Pbind
//
//  Created by galen on 15/2/26.
//  Copyright (c) 2015年 galen. All rights reserved.
//
//  Input lookup order
//     +-------+
//  #1 | @1-@3 |
//     +---/---+
//  #2 | @2    |
//     +--|----+
//  #3 | @1    |
//     +-------+
//  ('#'=row, '@'=tag)
//

#import "PBForm.h"
#import "PBMapperProperties.h"
#import "PBExpression.h"
#import "PBFormAccessory.h"
#import "PBInput.h"
#import "PBClient.h"
#import "PBFormController.h"
#import "PBTextView.h"
#import "UIView+Pbind.h"
#import "PBString.h"
#import "UIButton+PBForm.h"
#import "PBDictionary.h"

//______________________________________________________________________________

NSString *const PBFormWillSubmitNotification = @"PBFormWillSubmit";
NSString *const PBFormDidSubmitNotification = @"PBFormDidSubmit";
NSString *const PBFormWillResetNotification = @"PBFormWillReset";
NSString *const PBFormDidResetNotification = @"PBFormDidReset";
NSString *const PBFormDidValidateNotification = @"PBFormDidValidate";

NSString *const PBFormValidateInputKey = @"PBFormValidateInput";
NSString *const PBFormValidateStateKey = @"PBFormValidateState";
NSString *const PBFormValidatePassedKey = @"PBFormValidatePassed";
NSString *const PBFormValidateTipsKey = @"PBFormValidateTips";

NSString *const PBFormHasHandledSubmitErrorKey = @"PBFormHasHandledSubmitError";

static CGFloat kKeyboardDuration = 0;
static UIViewAnimationOptions kKeyboardAnimationOptions = 0;
static NSInteger kMinKeyboardHeightToScroll = 200;

@interface PBClient (Private)

- (void)_loadRequest:(PBRequest *)request mapper:(PBClientMapper *)mapper notifys:(BOOL)notifys complection:(void (^)(PBResponse *))complection;

@end

@interface PBScrollView (Private)

- (void)didInitRowViews;

@end

@interface PBForm () <PBFormAccessoryDelegate, PBFormAccessoryDataSource>
{
    NSMutableArray  *_inputs;
    NSMutableArray  *_availableKeyboardInputs;
    PBFormAccessory *_accessory;
    UILabel         *_indicator;
    
    UIView<PBInput> *_presentedInput;
    UIView<PBInput> *_presentingInput;
    
    CGFloat          _keyboardHeight;
    CGFloat          _offsetYForPresentingInput;
    
    PBDictionary    *_inputTexts;
    PBDictionary    *_inputValues;
}

@end

@interface PBForm (Private)

- (PBDictionary *)inputTexts;
- (PBDictionary *)inputValues;

@end

@implementation PBForm

- (void)config {
    [super config];
    [self setIndicating:PBFormIndicatingMaskInputInvalid];
}

- (void)didInitRowViews {
    [super didInitRowViews];
    
    [self initInputs];
    [self initAccessory];
    [self initIndicator];
    [self observeInputNotifications];
    _formFlags.needsReloadAccessoryView = 1;
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window) {
        
    } else {
        [self unobserveInputNotifications];
    }
}

- (void)initAccessory {
    if (_accessory != nil) {
        return;
    }
    // Input accessory
    _accessory = [[PBFormAccessory alloc] init];
    _accessory.delegate = self;
    _accessory.dataSource = self;
}

- (void)initIndicator {
    if (_indicator != nil) {
        [self bringSubviewToFront:_indicator];
        return;
    }
    // Input indicator
    _indicator = [[UILabel alloc] init];
    _indicator.backgroundColor = [UIColor clearColor];
    _indicator.layer.borderWidth = .5;
    _indicator.layer.borderColor = [self tintColor].CGColor;
    _indicator.textColor = [UIColor redColor];
    _indicator.textAlignment = NSTextAlignmentCenter;
    _indicator.userInteractionEnabled = NO;
    _indicator.alpha = 0;
    [self addSubview:_indicator];
}

- (void)dealloc
{
    _availableKeyboardInputs = nil;
    _inputs = nil;
    _indicator = nil;
    _accessory = nil;
    _presentedInput = nil;
    _presentingInput = nil;
    _delegateInterceptor = nil;
    _formDelegate = nil;
}

- (void)observeInputNotifications {
    // Keyboard
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    // TextField
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(inputDidBegin:) name:UITextFieldTextDidBeginEditingNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(inputDidChange:) name:UITextFieldTextDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(inputDidEnd:) name:UITextFieldTextDidEndEditingNotification object:nil];
    // TextView
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(inputDidBegin:) name:UITextViewTextDidBeginEditingNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(inputDidChange:) name:UITextViewTextDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(inputDidEnd:) name:UITextViewTextDidEndEditingNotification object:nil];
}

- (void)unobserveInputNotifications {
    // Keyboard
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    // TextField
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextFieldTextDidBeginEditingNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextFieldTextDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextFieldTextDidEndEditingNotification object:nil];
    // TextView
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextViewTextDidBeginEditingNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextViewTextDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextViewTextDidEndEditingNotification object:nil];
}

- (void)initInputs {
    if (_inputs != nil) {
        return;
    }
    
    _inputs = [[NSMutableArray alloc] init];
    [self addInputsForView:self];
    
    // Init input texts and values for observable
    _inputTexts = [PBDictionary dictionaryWithCapacity:_inputs.count];
    _inputValues = [PBDictionary dictionaryWithCapacity:_inputs.count];
    for (id<PBInput> input in _inputs) {
        [self updateObservedTextsAndValuesForInput:input];
    }
    
    // Init submit input
    if (_submitInput != nil) {
        if ([_submitInput isKindOfClass:[UIControl class]]) {
            UIControl *submitControl = (id)_submitInput;
            [submitControl addTarget:self action:@selector(onSubmit:) forControlEvents:UIControlEventTouchUpInside];
        }
    }
}

- (void)initAvailableKeyboardInputs {
    if (_inputs == nil) {
        _availableKeyboardInputs = nil;
        return;
    }
    
    if (_availableKeyboardInputs == nil) {
        _availableKeyboardInputs = [NSMutableArray arrayWithCapacity:[_inputs count]];
    } else {
        [_availableKeyboardInputs removeAllObjects];
    }
    for (UIView *input in _inputs) {
        // Check if responsive
        if (![input isUserInteractionEnabled]) {
            continue;
        }
        if (![input canBecomeFirstResponder]) {
            continue;
        }
        if ([input respondsToSelector:@selector(isEnabled)] && ![(id)input isEnabled]) {
            continue;
        }
        // Check if visible
        if ([self __isInvisibleOfInput:input]) {
            continue;
        }
        
        [_availableKeyboardInputs addObject:input];
    }
    // Order inputs
    [_availableKeyboardInputs sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        CGPoint p1 = [obj1 convertPoint:CGPointZero toView:self.window];
        CGPoint p2 = [obj2 convertPoint:CGPointZero toView:self.window];
        if (p1.y < p2.y) {
            return NSOrderedAscending;
        } else if (p1.y > p2.y) {
            return NSOrderedDescending;
        } else {
            if (p1.x < p2.x) {
                return NSOrderedAscending;
            } else {
                return NSOrderedDescending;
            }
        }
    }];
}

- (void)addInputsForView:(UIView *)view {
    for (UIView *subview in view.subviews) {
        if ([subview conformsToProtocol:@protocol(PBInput)]) {
            id<PBInput> input = (id)subview;
            if (input.name != nil) {
                [_inputs addObject:subview];
            } else if ([input isKindOfClass:[UIButton class]] && [[(UIButton *)input type] isEqualToString:@"submit"]) {
                _submitInput = (id)subview;
            }
        }
        
        // Recursive
        [self addInputsForView:subview];
    }
}

- (id<PBInput>)inputForName:(NSString *)name
{
    for (id<PBInput> input in _inputs) {
        if ([[input name] isEqualToString:name]) {
            return input;
        }
    }
    return nil;
}

#pragma mark -
#pragma mark - Properties

- (void)setValidateState:(PBFormValidateState)validateState {
    _formFlags.validateState = validateState;
}

- (PBFormValidateState)validateState {
    return _formFlags.validateState;
}

- (BOOL)isInvalid {
    return [_invalidInputNames count] != 0;
}

- (BOOL)isInvalidForName:(NSString *)name {
    return [_invalidInputNames containsObject:name];
}

- (BOOL)isChanged {
    if (_initialParams == nil) {
        return NO;
    }
    NSDictionary *params = [self params];
    if ([params count] != [_initialParams count]) {
        return YES;
    }
    for (NSString *key in _initialParams) {
        if (![params[key] isEqual:_initialParams[key]]) {
            return YES;
        }
    }
    return NO;
}

- (void)setData:(id)data {
    if (self.data == nil) {
        _initialData = data;
    }
    [super setData:data];
}

#pragma mark - 
#pragma mark - Actions

- (void)reset
{
    if ([self.formDelegate respondsToSelector:@selector(formShouldReset:)]) {
        if (![self.formDelegate formShouldReset:self]) {
            return;
        }
    }
    [self endEditing:YES];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:PBFormWillResetNotification object:self];
    if ([self.formDelegate respondsToSelector:@selector(formWillReset:)]) {
        [self.formDelegate formWillReset:self];
    }
    
    // Reset texts
    for (id<PBInput> input in _inputs) {
        if ([input respondsToSelector:@selector(reset)]) {
            [input reset];
        } else {
            [input setValue:nil];
        }
    }
    // Reset values
    void (^complection)(PBResponse *) = ^(PBResponse *response) {
        [self pb_loadData:[response data]];
        NSDictionary *userInfo = (response == nil) ? nil : @{PBResponseKey:response};
        [[NSNotificationCenter defaultCenter] postNotificationName:PBFormDidResetNotification
                                                            object:self
                                                          userInfo:userInfo];
        if ([self.formDelegate respondsToSelector:@selector(form:didReset:)]) {
            [self.formDelegate form:self didReset:response];
        }
        // Reset params
        _initialParams = nil;
        // Scroll to top
        CGPoint offset = self.contentOffset;
        [self setContentOffset:CGPointMake(offset.x, -self.contentInset.top) animated:YES];
    };
    PBClient *client = [self resetClient];
    if (client == nil) {
        PBResponse *response = [[PBResponse alloc] init];
        response.data = _initialData;
        complection(response);
    } else {
        // Post action
        Class requestClass = [[client class] requestClass];
        PBRequest *request = [[requestClass alloc] init];
        request.action = _resetClientAction;
        [client _loadRequest:request mapper:nil notifys:NO complection:complection];
    }
}

- (void)submit
{
    PBClient *client = [self submitClient];
    if (client == nil) {
        return;
    }
    
    [self endEditing:YES];
    
    // Validate inputs
    id<PBInput> invalidInput = nil;
    for (id<PBInput> input in _inputs) {
        if (![self validateInput:input forState:PBFormValidateStateSubmitting]) {
            invalidInput = input;
            break;
        }
    }
    if (invalidInput != nil) {
        [self scrollToInput:(id)invalidInput animated:YES completion:^(BOOL finish) {
            // Blink
            if (self.indicating & PBFormIndicatingMaskInputInvalid) {
                _indicator.layer.borderColor = [UIColor redColor].CGColor;
                _indicator.alpha = 0;
                [UIView animateWithDuration:.5 delay:0 options:UIViewAnimationOptionRepeat animations:^{
                    [UIView setAnimationRepeatCount:2];
                    _indicator.alpha = 1;
                } completion:^(BOOL finished) {
//                    _indicator.alpha = 0;
                }];
            }
        }];
        return;
    }
    
    // Build up params
    NSDictionary *params = [self submitParams];
    // User validating
    if ([self.formDelegate respondsToSelector:@selector(formShouldSubmit:parameters:)]) {
        if (![self.formDelegate formShouldSubmit:self parameters:params]) {
            return;
        }
    }
    if (self.clientParams != nil) {
        NSMutableDictionary *aParams = [NSMutableDictionary dictionaryWithDictionary:params];
        [aParams setValuesForKeysWithDictionary:self.clientParams];
        params = aParams;
    }
    if (self.mode == PBFormModeUpdate && [params count] == 0) {
        return;
    }
    // Post action
    Class requestClass = [[client class] requestClass];
    PBRequest *request = [[requestClass alloc] init];
    request.action = _submitClientAction;
    request.params = params;
    [[NSNotificationCenter defaultCenter] postNotificationName:PBFormWillSubmitNotification object:self];
    if ([self.formDelegate respondsToSelector:@selector(formWillSubmit:)]) {
        [self.formDelegate formWillSubmit:self];
    }
    [client _loadRequest:request mapper:nil notifys:NO complection:^(PBResponse *response) {
        // Forward to delegate
        BOOL handledError = NO;
        if ([self.formDelegate respondsToSelector:@selector(form:didSubmit:handledError:)]) {
            [self.formDelegate form:self didSubmit:response handledError:&handledError];
        }
        // Send notification
        NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] initWithCapacity:2];
        [userInfo setObject:@(handledError) forKey:PBFormHasHandledSubmitErrorKey];
        if (response != nil) {
            [userInfo setObject:response forKey:PBResponseKey];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:PBFormDidSubmitNotification
                                                            object:self
                                                          userInfo:userInfo];
    }];
}

- (NSDictionary *)params {
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    for (id<PBInput> input in _inputs) {
        // Check name
        NSString *name = [input name];
        if ([name isEqual:[NSNull null]] || [name length] == 0) {
            continue;
        }
        // Check value
        BOOL isEmpty = NO;
        id value = [input value];
        if (value == nil) {
            isEmpty = YES;
        } else if ([input respondsToSelector:@selector(isEmpty)]) {
            isEmpty = [input isEmpty];
        }
        
        if (self.mode == PBFormModeUpdate) {
            if (isEmpty) {
                // TODO: Build up empty params
                value = @"";
            }
        } else {
            if (isEmpty) {
                continue;
            }
        }
        // Build up params
        if ([value isKindOfClass:[NSArray class]]) {
            NSArray *names = [name componentsSeparatedByString:@","];
            NSInteger count = MIN([names count], [value count]);
            for (NSInteger index = 0; index < count; index++) {
                NSString *aName = [names objectAtIndex:index];
                id aValue = [value objectAtIndex:index];
                [params setObject:aValue forKey:aName];
            }
        } else if ([value isKindOfClass:[NSDictionary class]]) {
            for (NSString *key in value) {
                [params setObject:[value objectForKey:key] forKey:key];
            }
        } else if ([value isKindOfClass:[NSDate class]]) {
            NSNumber *t = [NSNumber numberWithLongLong:[value timeIntervalSince1970]];
            [params setObject:t forKey:name];
        } else {
            [params setObject:value forKey:name];
        }
    }
    return params;
}

- (NSDictionary *)submitParams {
    NSDictionary *params = [self params];
    if (self.mode == PBFormModeUpdate) {
        if (_initialParams == nil) {
            params = nil;
        } else {
            NSMutableDictionary *aParams = [NSMutableDictionary dictionaryWithDictionary:params];
            for (NSString *key in _initialParams) {
                if ([aParams[key] isEqual:_initialParams[key]]) {
                    [aParams removeObjectForKey:key];
                }
            }
            params = aParams;
        }
    }
    return params;
}

- (void)onSubmit:(id)sender {
    [self submit];
}

- (PBClient *)submitClient {
    if (_submitClient == nil && _action != nil) {
        NSURL *url = [NSURL URLWithString:_action];
        NSString *scheme = [url scheme];
        if (![scheme isEqualToString:@"client"]) {
            return nil;
        }
        NSString *clientName = [url host];
        _submitClient = [PBClient clientWithName:clientName];
        _submitClientAction = [url path];
    }
    return _submitClient;
}

- (PBClient *)resetClient {
    if (_resetClient == nil && _resetAction != nil) {
        NSURL *url = [NSURL URLWithString:_resetAction];
        NSString *scheme = [url scheme];
        if (![scheme isEqualToString:@"client"]) {
            return nil;
        }
        NSString *clientName = [url host];
        _resetClient = [PBClient clientWithName:clientName];
        _resetClientAction = [url path];
    }
    return _resetClient;
}

#pragma mark - Notifications

- (void)keyboardWillShow:(NSNotification *)notification
{
    if (kKeyboardAnimationOptions == 0) {
        kKeyboardAnimationOptions = [[notification.userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] intValue] << 16;
    }
    if (kKeyboardDuration == 0) {
        kKeyboardDuration = [[notification.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
    }
    _keyboardHeight = [[notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size.height;
    if (!_formFlags.isWaitingForKeyboardShow && !_formFlags.hasScrollToInput) {  // with some 3rd input method, keyboard was presented up slowly, add this to avoid shaking with scrolling
        [self scrollToInput:_presentingInput animated:YES];
    }
}

- (void)keyboardWillHide:(NSNotification *)notification
{
    /*
     * Restore tableView's content offset
     */
    CGPoint offset = [self contentOffset];
    UIEdgeInsets insets = [self contentInset];
    CGFloat maxY = self.contentSize.height + insets.top + insets.bottom - self.bounds.size.height;
    maxY = MAX(maxY, 0);
    if (offset.y > maxY) {
        offset.y = maxY;
        [self animateAsKeyboardWithAnimations:^{
            [self setContentOffset:offset];
        } completion:nil];
    }
}

- (void)inputDidBegin:(NSNotification *)notification
{
    // Init input accessory
    id input = notification.object;
    if (![_inputs containsObject:input]) {
        return;
    }
    NSString *type = ((id<PBInput>) input).type;
    if (type == nil) {
        return;
    }
    
    [input setInputAccessoryView:_accessory];
    _presentingInput = input;
    
    if (_formFlags.needsReloadAccessoryView) {
        // If the input presented by user tapped, reset accessory's toggle index
        [self initAvailableKeyboardInputs];
        NSInteger index = [_availableKeyboardInputs indexOfObject:input];
        [_accessory setToggledIndex:index];
        _formFlags.needsReloadAccessoryView = 0;
    }
    [_accessory reloadData];
    [input reloadInputViews];
    
    // Init indicator
    if (self.indicating & PBFormIndicatingMaskInputFocus) {
        _indicator.layer.borderColor = [self tintColor].CGColor;
        _indicator.text = nil;
        _indicator.alpha = 1;
    } else {
        _indicator.alpha = 0;
    }
    
    // Wait for `keyboardWillShow' calling to center the input to visible rect
    _formFlags.isWaitingForKeyboardShow = YES;
    _formFlags.hasScrollToInput = NO;
    CGFloat seconds = _formFlags.isWaitingForAutomaticAdjustOffset ? .5 : .05;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        _formFlags.isWaitingForKeyboardShow = NO;
        if (_keyboardHeight > kMinKeyboardHeightToScroll) { // with some 3rd input method, keyboard was presented up slowly, add this to avoid shaking on scrolling
            if (!_formFlags.hasScrollToInput) {
                _formFlags.hasScrollToInput = YES;
                [self scrollToInput:_presentingInput animated:YES];
            }
        }
    });
}

- (void)inputDidChange:(NSNotification *)notification
{
    id input = notification.object;
    if (![_presentingInput isEqual:input]) {
        return;
    }
    
    // Validate
    BOOL valid = YES;
    if (self.validateState & PBFormValidateStateChanged) {
        valid = [self validateInput:input forState:PBFormValidateStateChanged];
        if (!valid) {
            return;
        }
    }
    
    // Update the observed values
    [self updateObservedTextsAndValuesForInput:input];
}

- (void)inputDidEnd:(NSNotification *)notification
{
    id input = notification.object;
    if (![_presentingInput isEqual:input]) {
        return;
    }
    
    _presentingInput = nil;
    _presentedInput = input;
    if ([self.formDelegate respondsToSelector:@selector(form:didEndEditingOnInput:)]) {
        [self.formDelegate form:self didEndEditingOnInput:(id)_presentedInput];
    }
    
    // Update the observed values
    [self updateObservedTextsAndValuesForInput:input];
    
    // If is end editing by pushing to another controller, set `isWaitingForAutomaticAdjustOffset' flag to make sure re-presenting the input to a correct visible rect
    UIViewController *supercontroller = [self supercontroller];
    UINavigationController *navigationController = [supercontroller navigationController];
    if (navigationController != nil && ![[[navigationController viewControllers] lastObject] isEqual:supercontroller]) {
        _formFlags.isWaitingForAutomaticAdjustOffset = YES;
    }
}

- (void)updateObservedTextsAndValuesForInput:(id<PBInput>)input {
    NSString *name = [input name];
    id value = [input value];
    NSString *text = [input respondsToSelector:@selector(text)] ? [input text] : value;
    _inputTexts[name] = text;
    _inputValues[name] = value;
}

#pragma mark - User Interaction

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    if (_initialParams == nil) {
        _formFlags.needsInitParams = 1;
    }

    UIView *view = [super hitTest:point withEvent:event];
    if (_presentedInput == nil || ![_presentingInput isEqual:view]) {
        if ([view conformsToProtocol:@protocol(PBInput)]) {
            id<PBInput> input = (id)view;
            if (input.type != nil) {
                _formFlags.needsReloadAccessoryView = 1;
            }
        }
    }
    
    // FIXME: Hack to large button click area, any better way?
    UITableViewCell *cell = nil;
    if ([view isKindOfClass:[UITableViewCell class]] /* iOS8 */) {
        cell = (id)view;
    } else if ([[[view class] description] isEqualToString:@"UITableViewCellScrollView"] /* iOS7 */) {
        cell = [view superviewWithClass:[UITableViewCell class]];
    }
    if (cell != nil && cell.accessoryType == UITableViewCellAccessoryDisclosureIndicator && (cell.contentView.frame.origin.x + cell.contentView.frame.size.width < point.x)) {
        // Hitting accessory view
        for (NSInteger index = 1; index < 20/*should be enough*/; index++) {
            UIView *subview = [view viewWithTag:index];
            if (subview == nil) {
                break;
            }
            if ([subview conformsToProtocol:@protocol(PBInput)]) {
                return subview;
            }
        }
    }
    
    return view;
}

- (BOOL)touchesShouldBegin:(NSSet *)touches withEvent:(UIEvent *)event inContentView:(UIView *)view
{
    BOOL ret = [super touchesShouldBegin:touches withEvent:event inContentView:view];
    /* Lazy init form params
     */
    if (_formFlags.needsInitParams) {
        _initialParams = [self params];
        for (id<PBInput> input in _inputs) {
            [self validateInput:input forState:PBFormValidateStateInitialized];
        }
        _formFlags.needsInitParams = 0;
    }
    /* If hit at a unresponsive view outside presenting input,
     * end editing
     */
    if (![view canBecomeFirstResponder] && ![view isKindOfClass:[UIControl class]]) {
        if (_presentingInput != nil && ![view isDescendantOfView:_presentedInput]) {
            [self endEditing:YES];
            return ret;
        }
    }
    
    return ret;
}

- (BOOL)endEditing:(BOOL)force
{
    // Dismiss the indicator
    [self animateAsKeyboardWithAnimations:^{
        [_indicator setFrame:CGRectZero];
        [_indicator setText:nil];
        if ([_presentingInput isKindOfClass:[PBInput class]]) {
            [(PBInput *)_presentingInput setSelected:NO];
        }
    } completion:nil];
    _keyboardHeight = 0;
    
    return [super endEditing:force];
}

#pragma mark - PBFormAccessoryDelegate

- (BOOL)accessoryShouldReturn:(PBFormAccessory *)accessory
{
    [self endEditing:YES];
    return YES;
}

#pragma mark - PBFormAccessoryDataSource

- (NSInteger)responderCountForAccessory:(PBFormAccessory *)accessory
{
    return [_availableKeyboardInputs count];
}

- (UIResponder *)accessory:(PBFormAccessory *)accessory responderForToggleAtIndex:(NSInteger)index
{
    return [_availableKeyboardInputs objectAtIndex:index];
}

- (NSArray *)accessory:(PBFormAccessory *)accessory barButtonItemsForResponderAtIndex:(NSInteger)index
{
    UIView *input = [_availableKeyboardInputs objectAtIndex:index];
    NSMutableArray *accessoryItems = nil;
    
    // Add `Clear' item
    if ([input respondsToSelector:@selector(acceptsClearOnAccessory)] && [(id)input acceptsClearOnAccessory]) {
        UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Clear", nil) style:UIBarButtonItemStylePlain target:self action:@selector(accessoryClearButtonItemClick:)];
        UIColor *tintColor = [self tintColor];
        [item setTitleTextAttributes:@{NSForegroundColorAttributeName:tintColor} forState:UIControlStateNormal];
        if (accessoryItems == nil) {
            accessoryItems = [[NSMutableArray alloc] init];
            [accessoryItems addObject:item];
        }
    }
    // Add user items
    if ([input respondsToSelector:@selector(accessoryItems)]) {
        NSArray *userItems = [(id)input accessoryItems];
        if (userItems != nil) {
            if (accessoryItems == nil) {
                accessoryItems = [NSMutableArray arrayWithArray:userItems];
            } else {
                [accessoryItems addObjectsFromArray:userItems];
            }
        }
    }
    
    return accessoryItems;
}

- (void)accessoryClearButtonItemClick:(id)sender
{
    if ([_presentingInput respondsToSelector:@selector(reset)]) {
        [_presentingInput reset];
    } else {
        [_presentingInput setValue:nil];
    }
    if ([_presentingInput isKindOfClass:[UIControl class]]) {
        [(UIControl *)_presentingInput sendActionsForControlEvents:UIControlEventEditingChanged];
    }
}

#pragma mark - UIScrollViewDelegate

- (void)setContentSize:(CGSize)contentSize
{
    if (_presentingInput != nil) {
        CGPoint offset = [self contentOffset];
        
        [super setContentSize:contentSize];
        
        [self setContentOffset:offset];
        // Re-scroll the presenting input to the center rect after content size changed
        [self scrollToInput:_presentingInput animated:YES];
    } else {
        [super setContentSize:contentSize];
    }
}

- (void)setContentOffset:(CGPoint)contentOffset {
    if (_formFlags.isWaitingForAutomaticAdjustOffset && _formFlags.isWaitingForKeyboardShow) {
        _formFlags.isWaitingForAutomaticAdjustOffset = NO;
        if (!_formFlags.hasScrollToInput) {
            _formFlags.hasScrollToInput = YES;
            // Re-scroll the presenting input to the center rect after owner controller re-showed
            [self scrollToInput:_presentingInput animated:YES];
        } else {
            [super setContentOffset:contentOffset];
        }
    } else {
        [super setContentOffset:contentOffset];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (_indicator.alpha != 0) {
        _indicator.alpha = 0;
    }
    [super scrollViewDidScroll:scrollView];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (_presentedInput != nil) {
        [self endEditing:YES];
    }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    if (_presentingInput != nil) {
        [self setContentOffset:CGPointMake(self.contentOffset.x, _offsetYForPresentingInput) animated:YES];
    }
    if ([_delegateInterceptor.receiver respondsToSelector:@selector(scrollViewWillEndDragging:withVelocity:targetContentOffset:)]) {
        [_delegateInterceptor.receiver scrollViewWillEndDragging:scrollView withVelocity:velocity targetContentOffset:targetContentOffset];
    }
}

#pragma mark - Helper

- (void)scrollToInput:(UIView<PBInput> *)input animated:(BOOL)animated
{
    [self scrollToInput:input animated:animated completion:nil];
}

- (void)scrollToInput:(UIView<PBInput> *)input animated:(BOOL)animated completion:(void (^)(BOOL finish))completion
{
    /*
     * Center the presenting input to tableView's visible rect
     */
    CGFloat keyboardY = [UIScreen mainScreen].bounds.size.height - _keyboardHeight;
    CGRect tableViewRect = [self convertRect:self.bounds toView:self.window];
    CGFloat visibleCenterY = (keyboardY - tableViewRect.origin.y) / 2;
    CGRect inputRect = [input convertRect:input.bounds toView:self];
    CGPoint offset = [self contentOffset];
    UIEdgeInsets insets = [self contentInset];
//    CGFloat maxOffsetY = [self contentSize].height + insets.top + insets.bottom - [self bounds].size.height + _keyboardHeight;
    offset.y = inputRect.origin.y + inputRect.size.height / 2 - visibleCenterY;
    offset.y = MIN(offset.y, inputRect.origin.y);
    offset.y = MAX(offset.y , -insets.top);
    
    // Move indicator
    CGFloat cornerRadius = 0;
    UITextField *tf = (id)input;
    if ([tf isKindOfClass:[UITextField class]]
        && tf.borderStyle == UITextBorderStyleRoundedRect) {
        cornerRadius = PBTextViewLeftMargin() + 1;
    } else {
        cornerRadius = input.layer.cornerRadius;
    }
    
    CGRect indicatorRect = inputRect;
    if ([input respondsToSelector:@selector(invalidIndicatorRect)]) {
        indicatorRect = [input invalidIndicatorRect];
        indicatorRect = [input convertRect:indicatorRect toView:self];
    }
    _offsetYForPresentingInput = offset.y;
    dispatch_block_t animation = ^{
        [self setContentOffset:offset];
        _indicator.layer.cornerRadius = cornerRadius;
        [_indicator setFrame:indicatorRect];
        if ([_presentedInput isKindOfClass:[PBInput class]]) {
            [(PBInput *)_presentedInput setSelected:NO];
        }
        if ([input isKindOfClass:[PBInput class]]) {
            [(PBInput *)input setSelected:YES];
        }
    };
    if (animated) {
        [self animateAsKeyboardWithAnimations:animation completion:completion];
    } else {
        animation();
        if (completion) {
            completion(YES);
        }
    }
}

- (void)animateAsKeyboardWithAnimations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion {
    [UIView animateWithDuration:kKeyboardDuration delay:0 options:kKeyboardAnimationOptions animations:animations completion:completion];
}

- (BOOL)validateInput:(id<PBInput>)input forState:(PBFormValidateState)state {
    if ([self __isInvisibleOfInput:(id)input]) {
        // FIXME: avoid cheing this each time
        return YES;
    }
    
    NSString *invalidTips = nil;
    // Validate for required field
    id value = [input value];
    BOOL required = NO;
    BOOL isEmpty = (value == nil);
    if ([input respondsToSelector:@selector(isRequired)]) {
        required = [input isRequired];
        if ([input respondsToSelector:@selector(isEmpty)]) {
            isEmpty = [input isEmpty];
        }
        if (required && isEmpty) {
            invalidTips = [input requiredTips];
            if (invalidTips == nil) {
                invalidTips = NSLocalizedString(@"Required", nil);
            }
            [self onValidateInput:input passed:NO tips:invalidTips forState:state];
            return NO;
        }
    }
    // Validate for validators
    if ((required || !isEmpty) && [input conformsToProtocol:@protocol(PBTextInputValidator)]) {
        id<PBTextInputValidator> textInput = (id)input;
        NSArray *validators = [textInput validators];
        if (validators != nil && [validators isKindOfClass:[NSArray class]]) {
            for (NSDictionary *validator in validators) {
                NSString *pattern = [validator objectForKey:@"pattern"];
                if (pattern.length != 0) {
                    NSString *text = value;
                    if (![text isKindOfClass:[NSString class]]) {
                        text = [value stringValue];
                    }
                    NSPredicate *test = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", pattern];
                    if (![test evaluateWithObject:text]){
                        invalidTips = [validator objectForKey:@"tips"];
                        if (invalidTips == nil) {
                            invalidTips = NSLocalizedString(@"Format error", nil);
                        }
                        [self onValidateInput:input passed:NO tips:invalidTips forState:state];
                        return NO;
                    }
                }
            }
        }
    }
    // User validating
    if ([self.formDelegate respondsToSelector:@selector(form:validateInput:tips:forState:)]) {
        if (![self.formDelegate form:self validateInput:input tips:&invalidTips forState:state]) {
            [self onValidateInput:input passed:NO tips:invalidTips forState:state];
            return NO;
        }
    }
    
    [self onValidateInput:input passed:YES tips:nil forState:state];
    return YES;
}

- (void)onValidateInput:(id<PBInput>)input passed:(BOOL)passed tips:(NSString *)tips forState:(PBFormValidateState)state {
    // Determine form invalid or not
    BOOL previousInvalid = [self isInvalid];
    if (!passed) {
        if (_invalidInputNames == nil) {
            _invalidInputNames = [[NSMutableArray alloc] init];
        }
        if (![_invalidInputNames containsObject:[input name]]) {
            [_invalidInputNames addObject:[input name]];
        }
    } else {
        if (_invalidInputNames != nil) {
            [_invalidInputNames removeObject:[input name]];
        }
    }
    BOOL currentInvalid = [self isInvalid];
    if (previousInvalid != currentInvalid) {
        if ([self.formDelegate respondsToSelector:@selector(formDidInvalidChanged:)]) {
            [self.formDelegate formDidInvalidChanged:self];
        }
    }
    // Send validate notification
    NSDictionary *baseInfo = @{PBFormValidateInputKey:input,
                               PBFormValidateStateKey:@(state),
                               PBFormValidatePassedKey:@(passed)};
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] initWithDictionary:baseInfo];
    if (tips != nil) {
        [userInfo setObject:tips forKey:PBFormValidateTipsKey];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:PBFormDidValidateNotification object:self userInfo:userInfo];
    // Send validate delegate
    if ([self.formDelegate respondsToSelector:@selector(form:didValidateInput:passed:tips:forState:)]) {
        [self.formDelegate form:self didValidateInput:input passed:passed tips:tips forState:state];
    }
}

- (BOOL)__isInvisibleOfInput:(UIView *)input {
    BOOL invisible = NO;
    UIView *superview = [input superview];
    while (superview != nil && ![superview isEqual:self]) {
        if (superview.hidden || superview.alpha == 0 || superview.frame.size.height == 0  || superview.frame.size.width == 0) {
            invisible = YES;
            break;
        }
        superview = [superview superview];
    }
    return invisible;
}

@end

@implementation PBForm (Private)

- (PBDictionary *)inputTexts {
    return _inputTexts;
}

- (PBDictionary *)inputValues {
    return _inputValues;
}

@end

