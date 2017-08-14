//
//  UIView+PBAction.m
//  Pods
//
//  Created by galen on 17/8/14.
//
//

#import "UIView+PBAction.h"
#import "UIView+Pbind.h"
#import "PBActionStore.h"

@interface _PBViewActionTapper : UITapGestureRecognizer

@property (nonatomic, strong) NSString *name;
@property (nonatomic, assign) BOOL ownerUserInteractionEnabled;

@end

@implementation _PBViewActionTapper

@end

@interface _PBViewActionEvent : NSObject

@property (nonatomic, strong) NSString *type;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, weak) NSDictionary *source;
@property (nonatomic, strong) PBActionMapper *mapper;

@end

@implementation _PBViewActionEvent

@end

@implementation UIView (PBAction)

static NSString *const kActionEventsKey = @"pb_actionEvents";

- (void)pb_registerAction:(NSDictionary *)action forEvent:(NSString *)eventName {
    NSString *type, *name;
    [self pb_getActionType:&type name:&name fromEvent:eventName];
    
    BOOL initialized = NO;
    BOOL finalized = NO;
    NSMutableDictionary *actionEvents = self.pb_actionEvents;
    if (actionEvents == nil) {
        if (action != nil) {
            initialized = YES;
            actionEvents = self.pb_actionEvents = [[NSMutableDictionary alloc] init];
            NSMutableArray *events = [[NSMutableArray alloc] init];
            _PBViewActionEvent *event = [[_PBViewActionEvent alloc] init];
            event.name = name;
            event.source = action;
            [events addObject:event];
            [actionEvents setObject:events forKey:type];
        } else {
            return;
        }
    } else {
        NSMutableArray *events = [actionEvents objectForKey:type];
        if (action == nil) {
            if (events != nil) {
                for (_PBViewActionEvent *event in events) {
                    if ([event.name isEqualToString:name]) {
                        [event.mapper unbind];
                        [events removeObject:event];
                        break;
                    }
                }
                if (events.count == 0) {
                    finalized = YES;
                    [actionEvents removeObjectForKey:type];
                    if (actionEvents.count == 0) {
                        self.pb_actionEvents = nil;
                    }
                }
            } else {
                return;
            }
        } else {
            _PBViewActionEvent *event = nil;
            if (events == nil) {
                initialized = YES;
                events = [[NSMutableArray alloc] init];
                [actionEvents setObject:events forKey:type];
            } else {
                for (_PBViewActionEvent *temp in events) {
                    if ([temp.name isEqualToString:name]) {
                        temp.mapper = nil;
                        temp.source = action;
                        event = temp;
                        break;
                    }
                }
            }
            if (event == nil) {
                event = [[_PBViewActionEvent alloc] init];
                event.name = name;
                event.source = action;
                [events addObject:event];
            }
        }
    }
    
    if ([type isEqualToString:@"click"]) {
        if ([self isKindOfClass:[UIControl class]]) {
            // Control event
            UIControl *control = (id) self;
            if (initialized) {
                [control addTarget:self action:@selector(_pb_internalHandleClick:) forControlEvents:UIControlEventTouchUpInside];
            } else if (finalized) {
                [control removeTarget:self action:@selector(_pb_internalHandleClick:) forControlEvents:UIControlEventTouchUpInside];
            }
        } else {
            // Tap gesture
            if (initialized) {
                _PBViewActionTapper *tapper = [[_PBViewActionTapper alloc] initWithTarget:self action:@selector(_pb_internalHandleClick:)];
                tapper.name = eventName;
                tapper.ownerUserInteractionEnabled = self.userInteractionEnabled;
                self.userInteractionEnabled = YES;
                [self addGestureRecognizer:tapper];
            } else if (finalized) {
                for (UIGestureRecognizer *recognizer in self.gestureRecognizers) {
                    if ([recognizer isKindOfClass:[_PBViewActionTapper class]]) {
                        self.userInteractionEnabled = ((_PBViewActionTapper *)recognizer).ownerUserInteractionEnabled;
                        [self removeGestureRecognizer:recognizer];
                        break;
                    }
                }
            }
        }
    }
}

- (void)_pb_internalHandleClick:(id)sender {
    NSMutableDictionary *actionEvents = self.pb_actionEvents;
    if (actionEvents == nil) {
        return;
    }
    
    NSArray *events = [actionEvents objectForKey:@"click"];
    if (events == nil) {
        return;
    }
    
    for (_PBViewActionEvent *event in events) {
        if (event.mapper == nil) {
            // Lazy init
            if (event.source == nil) {
                continue;
            }
            event.mapper = [PBActionMapper mapperWithDictionary:event.source];
            if (event.mapper == nil) {
                continue;
            }
        }
        
        [[PBActionStore defaultStore] dispatchActionWithActionMapper:event.mapper sender:self context:self data:nil];
    }
}

- (NSMutableDictionary *)pb_actionEvents {
    return [self valueForAdditionKey:kActionEventsKey];
}

- (void)setPb_actionEvents:(NSMutableDictionary *)pb_actionEvents {
    [self setValue:pb_actionEvents forAdditionKey:kActionEventsKey];
}

- (void)pb_unbindActionMappers {
    NSArray *events = [self.pb_actionEvents allValues];
    if (events == nil) {
        return;
    }
    
    for (_PBViewActionEvent *event in events) {
        if (event.mapper != nil) {
            [event.mapper unbind];
        }
    }
    self.pb_actionEvents = nil;
}

- (NSDictionary *)pb_actionForEvent:(NSString *)eventName {
    NSString *type, *name;
    [self pb_getActionType:&type name:&name fromEvent:eventName];
    
    NSArray *events = [self.pb_actionEvents objectForKey:type];
    if (events == nil) {
        return nil;
    }
    
    for (_PBViewActionEvent *event in events) {
        if ([event.name isEqualToString:name]) {
            return event.source;
        }
    }
    return nil;
}

- (void)pb_getActionType:(NSString **)outType name:(NSString **)outName fromEvent:(NSString *)eventName {
    // Event: `![type]+[name]'
    NSString *type;
    NSString *name = @"";
    NSInteger aliasPos = [eventName rangeOfString:@"+"].location;
    if (aliasPos == NSNotFound) {
        type = eventName;
    } else {
        type = [eventName substringToIndex:aliasPos];
        name = [eventName substringFromIndex:aliasPos + 1];
    }
    
    *outType = type;
    *outName = name;
}

@end
