//
//  UIView+Pbind.m
//  Pbind
//
//  Created by galen on 15/2/12.
//  Copyright (c) 2015年 galen. All rights reserved.
//

#import "UIView+Pbind.h"
#import "Pbind+API.h"
#import "PBClient.h"
#import "PBMapper.h"
#import "PBMutableExpression.h"
#import "PBClientMapper.h"
#import "PBArray.h"
#import "PBPropertyUtils.h"
#import "PBValueParser.h"
#import "PBViewController.h"

NSString *const PBViewDidStartLoadNotification = @"PBViewDidStartLoadNotification";
NSString *const PBViewDidFinishLoadNotification = @"PBViewDidFinishLoadNotification";
NSString *const PBViewHasHandledLoadErrorKey = @"PBViewHasHandledLoadError";

@interface PBClient (Private)

- (void)_loadRequest:(PBRequest *)request mapper:(PBClientMapper *)mapper notifys:(BOOL)notifys complection:(void (^)(PBResponse *))complection;

@end

@interface UIView (Pbind_Private)

@property (nonatomic, strong) NSArray *_pbClients;
@property (nonatomic, strong) NSArray *_pbClientMappers;

@end

@implementation UIView (Pbind)

@dynamic clients;
@dynamic data;

#pragma mark -
#pragma mark - Override methods

- (void)didMoveToWindow
{
    if (self.window == nil) {
        if (self.pb_loading) {
            // If super controller is neither a singleton nor a child of `UITabBarController', mark interrupted flag to reload at next appearance
            if (![[[[self supercontroller] navigationController] parentViewController] isKindOfClass:[UITabBarController class]]) {
                self.pb_interrupted = YES;
                [self pb_cancelPull];
            }
        }
    } else {
        if (self.plist != nil) {
            if (self._pbPlistURL == nil) {
                [self pb_setInitialData:self.data];
                self._pbPlistURL = PBResourceURL(self.plist, @"plist");
                dispatch_async(dispatch_get_global_queue(0, 0), ^{
                   dispatch_sync(dispatch_get_main_queue(), ^{
                       [self _pb_initData];
                   });
                });
            }
        } else {
            if ([[self valueForAdditionKey:@"pb_expressible"] boolValue]) {
                [self _pb_initData];
            }
        }
        
        if (self.pb_interrupted) {
            self.pb_interrupted = NO;
            [self pb_repullData];
        }
    }
}

- (NSArray *)pb_clientMappers
{
    if (self._pbClientMappers != nil) return self._pbClientMappers;
    
    // Lazy init
    if (self.clients == nil) {
        return nil;
    } else {
        NSMutableArray *mappers = [NSMutableArray arrayWithCapacity:self.clients.count];
        for (id data in self.clients) {
            PBClientMapper *mapper = [PBClientMapper mapperWithDictionary:data owner:self];
            [mappers addObject:mapper];
        }
        self._pbClientMappers = mappers;
        return mappers;
    }
}

- (NSArray *)pb_clients
{
    if (self._pbClients != nil) return self._pbClients;
    
    if (self.pb_clientMappers == nil) return nil;
    
    NSMutableArray *clients = [NSMutableArray arrayWithCapacity:self.clients.count];
    for (PBClientMapper *mapper in self.pb_clientMappers) {
        PBClient *client = [PBClient clientWithName:mapper.clazz];
        client.delegate = (id) self;
        [clients addObject:client];
    }
    self._pbClients = clients;
    return clients;
}

- (PBMapper *)pb_mapper
{
    // Lazy init
    if (self.PB_internalMapper == nil) {
        if (self._pbPlistURL != nil) {
            self.PB_internalMapper = [PBMapper mapperWithContentsOfURL:self._pbPlistURL];
        }
    }
    return self.PB_internalMapper;
}

- (BOOL)pb_loading
{
    return self.pb_loadingCount > 0;
}

- (void)pb_pullData
{
    [self pb_pullDataWithPreparation:nil transformation:nil];
}

- (BOOL)pb_canPullData
{
    return (!self.pb_loading && self.pb_clientMappers != nil && self.pb_clients != nil);
}

- (void)pb_pullDataWithPreparation:(void (^)(void))preparation
                    transformation:(id (^)(id, NSError *))transformation
{
    if (![self pb_canPullData]) {
        return;
    }
    
    if (preparation) {
        preparation();
    }
    
    // Notify loading start
    [[NSNotificationCenter defaultCenter] postNotificationName:PBViewDidStartLoadNotification object:self];
    
    // Unbind
    [self pb_unbindAll];
    
    self.pb_preparation = preparation;
    self.pb_transformation = transformation;
    NSInteger N = self.pb_clients.count;
    self.pb_loadingCount = (int) N;
    
    // Init null data
    if (self.data == nil) {
        self.data = [PBArray arrayWithCapacity:self.clients.count];
        for (NSInteger i = 0; i < N; i++) {
            [self.data addObject:[NSNull null]];
        }
    }
    
    // Load request parallel
    for (NSInteger i = 0; i < N; i++) {
        PBClient *client = [self.pb_clients objectAtIndex:i];
        [client cancel];

        PBClientMapper *mapper = [self.pb_clientMappers objectAtIndex:i];
        [mapper updateWithData:self.data andView:self];
        
        Class requestClass = [client.class requestClass];
        PBRequest *request = [[requestClass alloc] init];
        request.action = mapper.action;
        request.params = mapper.params;
        request.requiresMutableResponse = mapper.mutable;
        
        if ([self respondsToSelector:@selector(view:shouldLoadRequest:)]) {
            BOOL flag = [self view:self shouldLoadRequest:request];
            if (!flag) {
                continue;
            }
        }
        if ([self.loadingDelegate respondsToSelector:@selector(view:shouldLoadRequest:)]) {
            BOOL flag = [self.loadingDelegate view:self shouldLoadRequest:request];
            if (!flag) {
                continue;
            }
        }
        
        [client _loadRequest:request mapper:nil notifys:NO complection:^(PBResponse *response) {
            BOOL handledError = NO;
            if ([self respondsToSelector:@selector(view:didFinishLoading:handledError:)]) {
                [self view:self didFinishLoading:response handledError:&handledError];
            }
            if ([self.loadingDelegate respondsToSelector:@selector(view:didFinishLoading:handledError:)]) {
                [self.loadingDelegate view:self didFinishLoading:response handledError:&handledError];
            }
            NSDictionary *userInfo = nil;
            if (response != nil) {
                userInfo = @{PBResponseKey:response, PBViewHasHandledLoadErrorKey:@(handledError)};
            } else {
                userInfo = @{PBViewHasHandledLoadErrorKey:@(handledError)};
            }
            
            id data = response.data;
            if (transformation) {
                data = transformation(data, response.error);
            }
            if (data == nil) {
                data = [NSNull null];
            }
            
            self.pb_preparation = nil;
            self.pb_transformation = nil;
            self.data[i] = data;
            self.pb_needsReload = YES;
            [self _pb_mapData:self.rootData];
            [self layoutIfNeeded];
            
            self.pb_loadingCount--;
            if (self.pb_loadingCount == 0) {
                // Notify loading finish
                [[NSNotificationCenter defaultCenter] postNotificationName:PBViewDidFinishLoadNotification object:self userInfo:userInfo];
            }
        }];
    }
}

- (void)_pb_initData {
    self.pb_needsReload = YES;
    
    PBMapper *mapper = [self pb_mapper];
    if (mapper == nil) {
        [self pb_initData];
        return;
    }
    
    [mapper initDataForView:self];
}

- (void)_pb_mapData:(id)data {
    PBMapper *mapper = [self pb_mapper];
    if (mapper == nil) {
        [self pb_mapData:data];
        return;
    }
    
    [mapper mapData:data forView:self];
}

- (void)pb_initData
{
    NSDictionary *properties = [self pb_constants];
    for (NSString *key in properties) {
        id value = [properties objectForKey:key];
        value = [PBValueParser valueWithString:value];
        [self pb_setValue:value forKeyPath:key];
    }
    
    [self pb_bindData];
    
    // Recursive
    if ([self respondsToSelector:@selector(reloadData)]) {
        
    } else {
        for (UIView *subview in [self subviews]) {
            [subview pb_initData];
        }
    }
    
    if (self.data == nil && self.clients != nil) {
        if (self.window == nil) {
            // Cause the plist value may be specify with expression `@xx', which requires the view's super controller. If window is nil, it means the super controller is also not yet ready.
            return;
        }
        
        [self pb_mapData:nil];
    }
    
    if ([self respondsToSelector:@selector(reloadData)]) {
        [(id)self reloadData];
    }
}

- (void)pb_bindData
{
    NSDictionary *properties = [self pb_expressions];
    for (NSString *key in properties) {
        PBExpression *exp = [properties objectForKey:key];
        [exp bindData:nil toTarget:self forKeyPath:key inContext:self];
    }
}

- (void)pb_mapData:(id)data
{
    NSDictionary *properties = [self pb_expressions];
    for (NSString *key in properties) {
        if ([self mappableForKeyPath:key]) {
            PBExpression *exp = [properties objectForKey:key];
            [exp mapData:data toTarget:self forKeyPath:key inContext:self];
        }
    }
    // Recursive
    if ([self respondsToSelector:@selector(reloadData)]) {
        
    } else {
        for (UIView *subview in [self subviews]) {
            [subview pb_mapData:data];
        }
    }
    
    if (self.data == nil && self.clients != nil) {
        [self pb_pullData];
    } else {
        if ([self respondsToSelector:@selector(reloadData)]) {
            [(id)self reloadData];
        }
    }
}

- (void)pb_mapData:(id)data forKey:(NSString *)key
{
    PBExpression *exp = [[self pb_expressions] objectForKey:key];
    if (exp == nil) {
        return;
    }
    
    [exp mapData:data toTarget:self forKeyPath:key inContext:self];
}

- (void)pb_repullData
{
    [self pb_pullDataWithPreparation:self.pb_preparation transformation:self.pb_transformation];
}

- (void)pb_loadData:(id)data
{
    [self setData:data];
    [[self pb_mapper] mapData:self.rootData forView:self];
    
    [self layoutIfNeeded];
}

- (void)pb_reloadPlist
{
    [self pb_unbindAll];
    
    // Re-init data if there is
    [self setData:[self pb_initialData]];
    
    [self pb_reloadPlistForView:self];
}

- (void)pb_reloadPlistForView:(UIView *)view {
    if (view.plist == nil) {
        for (UIView *subview in view.subviews) {
            [self pb_reloadPlistForView:subview];
        }
        return;
    }
    
    // Reset the plist mapper
    view._pbPlistURL = PBResourceURL(view.plist, @"plist");
    view.PB_internalMapper = nil;
    PBMapper *mapper = [view pb_mapper];
    
    // Reset all the PBMapper properties for self and subviews
    [self _pb_resetMappersForView:view];
    
    [mapper initDataForView:view];
    if ([view respondsToSelector:@selector(reloadData)]) {
        view.pb_needsReload = YES;
    }
    [mapper mapData:view.rootData forView:view];
}

- (void)pb_reloadClient
{
    [self pb_reloadClientForView:self];
}

- (BOOL)pb_reloadClientForView:(UIView *)view {
    if (view.pb_clientMappers != nil) {
        [view pb_repullData];
        return YES;
    }
    
    for (UIView *subview in view.subviews) {
        if ([self pb_reloadClientForView:subview]) {
            return YES;
        }
    }
    return NO;
}

- (void)pb_unbindAll
{
    [self _pb_unbindView:self];
    [self _pb_didUnbindView:self];
}

- (void)pb_unbind
{
    NSDictionary *expressions = [self pb_expressions];
    if (expressions != nil) {
        for (NSString *key in expressions) {
            PBExpression *expression = [expressions objectForKey:key];
            [expression unbind:self forKeyPath:key];
        }
    }
    
    NSArray *mappers = [self pb_mappersForBinding];
    if (mappers != nil) {
        for (PBMapper *mapper in mappers) {
            [mapper unbind];
        }
    }
}

- (void)pb_didUnbind
{
    
}

- (NSArray *)pb_mappersForBinding {
    return nil;
}

- (void)_pb_didUnbindView:(UIView *)view {
    [view pb_didUnbind];
    for (UIView *subview in view.subviews) {
        [self _pb_didUnbindView:subview];
    }
}

- (void)_pb_resetView:(UIView *)view {
    [view pb_reset];
    for (UIView *subview in view.subviews) {
        [self _pb_resetView:subview];
    }
}

- (void)pb_reset
{
    self.data = nil;
    if ([self respondsToSelector:@selector(reloadData)]) {
        self.pb_needsReload = YES;
    }
}

- (void)_pb_unbindView:(UIView *)view {
    [view pb_unbind];
    
    for (UIView *subview in view.subviews) {
        [self _pb_unbindView:subview];
    }
}

- (void)_pb_resetMappersForView:(UIView *)view {
    if ([view respondsToSelector:@selector(pb_resetMappers)]) {
        [(id) view pb_resetMappers];
    }
    for (UIView *subview in view.subviews) {
        [self _pb_resetMappersForView:subview];
    }
}

- (void)pb_cancelPull
{
    if (self.pb_clients == nil) return;
    
    for (PBClient *client in self.pb_clients) {
        [client cancel];
    }
    self.pb_loadingCount = 0;
}

#pragma mark -
#pragma mark - KVC

- (void)pb_setValue:(id)value forKeyPath:(NSString *)key
{
    if ([key length] > 1 && [key characterAtIndex:0] == '+') {
        [self setValue:value forAdditionKey:[key substringFromIndex:1]];
    } else {
        id target = self;
        NSArray *keys = [key componentsSeparatedByString:@"."];
        NSUInteger N = keys.count;
        if (N > 1) {
            int i = 0;
            for (; i < N - 1; i++) {
                key = keys[i];
                if ([key characterAtIndex:0] == '@') {
                    key = [key substringFromIndex:1];
                    target = [target viewWithAlias:key];
                } else {
                    target = [target valueForKey:key];
                }
            }
            key = keys[i];
        }
        
        // Safely set value for key
        [PBPropertyUtils setValue:value forKey:key toObject:target failure:^{
            // Remove the unavailable key from constants and expressions
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF != %@", key];
            NSArray *properties = @[@"pb_constants", @"pb_expressions"];
            for (NSString *property in properties) {
                NSDictionary *value = [self valueForAdditionKey:property];
                if (value == nil) {
                    continue;
                }
                
                NSArray *keys = [value allKeys];
                NSArray *availableKeys = [keys filteredArrayUsingPredicate:predicate];
                if (keys.count != availableKeys.count) {
                    value = [value dictionaryWithValuesForKeys:availableKeys];
                    [self setValue:value forAdditionKey:property];
                }
            }
        }];
    }
}

- (id)pb_valueForKeyPath:(NSString *)key
{
    id target = self;
    NSArray *keys = [key componentsSeparatedByString:@"."];
    NSUInteger N = keys.count;
    if (N > 1) {
        int i = 0;
        for (; i < N - 1; i++) {
            key = keys[i];
            if ([key characterAtIndex:0] == '@') {
                key = [key substringFromIndex:1];
                target = [target viewWithAlias:key];
            } else {
                target = [target valueForKey:key];
            }
        }
        key = keys[i];
    }
    
    return [target valueForKey:key];
}

- (void)setMappable:(BOOL)mappable forKeyPath:(NSString *)keyPath
{
    if (self.pb_unmappableKeys == nil) {
        if (!mappable) {
            self.pb_unmappableKeys = [[NSMutableArray alloc] init];
            [self.pb_unmappableKeys addObject:keyPath];
        }
    } else {
        if (mappable) {
            [self.pb_unmappableKeys removeObject:keyPath];
        } else if (![self.pb_unmappableKeys containsObject:keyPath]) {
            [self.pb_unmappableKeys addObject:keyPath];
        }
    }
}

- (BOOL)mappableForKeyPath:(NSString *)keyPath
{
    id target = self;
    NSString *key = keyPath;
    NSArray *keys = [key componentsSeparatedByString:@"."];
    NSUInteger N = keys.count;
    if (N > 1) {
        int i = 0;
        for (; i < N - 1; i++) {
            key = keys[i];
            if ([key characterAtIndex:0] == '@') {
                key = [key substringFromIndex:1];
                target = [target viewWithAlias:key];
            } else {
                id temp = [target valueForKey:key];
                if (![temp isKindOfClass:[UIView class]]) {
                    break;
                }
                target = temp;
            }
        }
        key = keys[i];
        while (i < N - 1) {
            key = [key stringByAppendingFormat:@".%@", keys[i]];
        }
    }
    
    NSArray *unmappableKeys = [target pb_unmappableKeys];
    return ![unmappableKeys containsObject:key];
}

- (void)setExpression:(NSString *)expression forKeyPath:(NSString *)keyPath
{
    PBMutableExpression *aExpression = [[PBMutableExpression alloc] initWithString:expression];
    if (aExpression == nil) {
        return;
    }
    
    NSMutableDictionary *expressions;
    if (self.pb_expressions == nil) {
        expressions = [[NSMutableDictionary alloc] init];
        self.pb_expressions = expressions;
    } else {
        expressions = [NSMutableDictionary dictionaryWithDictionary:self.pb_expressions];
    }
    [expressions setObject:aExpression forKey:keyPath];
    [self setValue:@(YES) forAdditionKey:@"pb_expressible"];
}

- (BOOL)hasExpressionForKeyPath:(NSString *)keyPath
{
    if (self.pb_expressions == nil) {
        return NO;
    }
    return [[self.pb_expressions allKeys] containsObject:keyPath];
}

- (UIViewController *)supercontroller
{
    id controller = self;
    while ((controller = [controller nextResponder]) != nil) {
        if ([controller isKindOfClass:[UIViewController class]]) {
            return PBVisibleController(controller);
        }
        
        if ([controller isKindOfClass:[UIWindow class]]) {
            return PBVisibleController([(id)controller rootViewController]);
        }
    }
    return controller;
}

- (id)rootData
{
    UIView * view = self;
    while (view != nil && view.plist == nil) {
        view = [view superview];
    }
    if (view == nil) {
        return nil;
    }
    return view.data;
}

- (id)superviewWithClass:(Class)clazz
{
    id view = [self superview];
    while (![view isKindOfClass:clazz]) {
        view = [view superview];
        if (view == nil) {
            break;
        }
    }
    return view;
}

- (UIView *)viewWithAlias:(NSString *)alias
{
    if (alias == nil) {
        return nil;
    }
    
    if ([alias isKindOfClass:[NSNumber class]]) {
        return [self viewWithTag:[alias integerValue]];
    }
    
    NSInteger tag;
    NSScanner *scanner = [NSScanner scannerWithString:alias];
    if ([scanner scanInteger:&tag]) {
        return [self viewWithTag:tag];
    }
    
    return [self _lookupViewWithAlias:alias];
}

- (UIView *)_lookupViewWithAlias:(NSString *)alias {
    if ([self.alias isEqualToString:alias]) {
        return self;
    }
    for (UIView *subview in self.subviews) {
        UIView *theView = [subview _lookupViewWithAlias:alias];
        if (theView != nil) {
            return theView;
        }
    }
    return nil;
}

#pragma mark - Addition properties

- (void)setPb_unmappableKeys:(NSMutableArray *)keys {
    [self setValue:keys forAdditionKey:@"pb_unmappableKeys"];
}

- (NSMutableArray *)pb_unmappableKeys {
    return [self valueForAdditionKey:@"pb_unmappableKeys"];
}

- (void)setPb_constants:(NSDictionary *)constants {
    NSDictionary *orgConstants = self.pb_constants;
    if (orgConstants != nil) {
        // Check if any key has been removed.
        NSArray *orgKeys = [orgConstants allKeys];
        NSArray *newKeys = [constants allKeys];
        NSArray *removedKeys;
        if (constants == nil || newKeys.count == 0) {
            removedKeys = orgKeys;
        } else {
            NSPredicate *pd = [NSPredicate predicateWithFormat:@"NOT SELF IN %@", [constants allKeys]];
            removedKeys = [[orgConstants allKeys] filteredArrayUsingPredicate:pd];
        }
        
        if (removedKeys.count > 0) {
            // Reset the default value for the key removed.
            [self setDefaultValueForKeys:removedKeys];
        }
    }
    
    [self setValue:constants forAdditionKey:@"pb_constants"];
}

- (NSDictionary *)pb_constants {
    return [self valueForAdditionKey:@"pb_constants"];
}

- (void)setDefaultValueForKeys:(NSArray *)keys {
    UIView *temp = [[[self class] alloc] init];
    for (NSString *key in keys) {
        id defaultValue = [temp valueForKeyPath:key];
        [self pb_setValue:defaultValue forKeyPath:key];
    }
}

- (void)setPb_expressions:(NSDictionary *)expressions {
    NSDictionary *orgExpressions = self.pb_expressions;
    if (orgExpressions != nil) {
        // Check if any key has been removed.
        NSArray *orgKeys = [orgExpressions allKeys];
        NSArray *newKeys = [expressions allKeys];
        NSArray *removedKeys;
        if (expressions == nil || newKeys.count == 0) {
            removedKeys = orgKeys;
        } else {
            NSPredicate *pd = [NSPredicate predicateWithFormat:@"NOT SELF IN %@", [expressions allKeys]];
            removedKeys = [[orgExpressions allKeys] filteredArrayUsingPredicate:pd];
        }
        
        if (removedKeys.count > 0) {
            // Clear the value for the key removed.
            for (NSString *key in removedKeys) {
                PBExpression *expression = [orgExpressions objectForKey:key];
                [expression unbind:self forKeyPath:key];
            }
            [self setDefaultValueForKeys:removedKeys];
        }
    }
    
    [self setValue:expressions forAdditionKey:@"pb_expressions"];
}

- (NSDictionary *)pb_expressions {
    return [self valueForAdditionKey:@"pb_expressions"];
}

- (void)set_pbPlistURL:(NSURL *)value {
    [self setValue:value forAdditionKey:@"_pbPlistURL"];
}

- (NSURL *)_pbPlistURL {
    return [self valueForAdditionKey:@"_pbPlistURL"];
}

- (void)set_pbClients:(NSArray *)value {
    [self setValue:value forAdditionKey:@"_pbClients"];
}

- (NSArray *)_pbClients {
    return [self valueForAdditionKey:@"_pbClients"];
}

- (void)set_pbClientMappers:(NSArray *)value {
    [self setValue:value forAdditionKey:@"_pbClientMappers"];
}

- (NSArray *)_pbClientMappers {
    return [self valueForAdditionKey:@"_pbClientMappers"];
}

- (void)setPB_internalMapper:(PBMapper *)value {
    [self setValue:value forAdditionKey:@"PB_internalMapper"];
}

- (PBMapper *)PB_internalMapper {
    return [self valueForAdditionKey:@"PB_internalMapper"];
}

- (void)setPlist:(NSString *)value {
    [self setValue:value forAdditionKey:@"plist"];
}

- (NSString *)plist {
    return [self valueForAdditionKey:@"plist"];
}

- (void)setClients:(NSArray *)value {
    [self setValue:value forAdditionKey:@"clients"];
}

- (NSArray *)clients {
    return [self valueForAdditionKey:@"clients"];
}

- (void)setData:(id)value {
    // If the `data' changed, then we needs to be reload
    id data = self.data;
    if (data == nil) {
        if (value != nil) {
            self.pb_needsReload = YES;
        }
    } else if (![data isEqual:value]) {
        self.pb_needsReload = YES;
    }
    
    [self setValue:value forAdditionKey:@"data"];
}

- (id)data {
    return [self valueForAdditionKey:@"data"];
}

- (void)pb_setInitialData:(id)value {
    [self setValue:value forAdditionKey:@"initialData"];
}

- (id)pb_initialData {
    return [self valueForAdditionKey:@"initialData"];
}

- (void)setLoadingDelegate:(id<PBViewLoadingDelegate>)value {
    [self setValue:value forAdditionKey:@"loadingDelegate"];
}

- (id<PBViewLoadingDelegate>)loadingDelegate {
    return [self valueForAdditionKey:@"loadingDelegate"];
}

- (void)setPb_preparation:(void (^)(void))value {
    [self setValue:value forAdditionKey:@"pb_preparation"];
}

- (void (^)(void))pb_preparation {
    return [self valueForAdditionKey:@"pb_preparation"];
}

- (void)setPb_transformation:(id (^)(id, NSError *))value {
    [self setValue:value forAdditionKey:@"pb_transformation"];
}

- (id (^)(id, NSError *))pb_transformation {
    return [self valueForAdditionKey:@"pb_transformation"];
}

- (void)setPb_complection:(void (^)(void))value {
    [self setValue:value forAdditionKey:@"pb_complection"];
}

- (void (^)(void))pb_complection {
    return [self valueForAdditionKey:@"pb_complection"];
}

- (void)setPb_loadingCount:(NSInteger)value {
    [self setValue:[NSNumber numberWithInteger:value] forAdditionKey:@"pb_loadingCount"];
}

- (NSInteger)pb_loadingCount {
    return [[self valueForAdditionKey:@"pb_loadingCount"] integerValue];
}

- (void)setPb_interrupted:(BOOL)value {
    [self setValue:[NSNumber numberWithBool:value] forAdditionKey:@"pb_interrupted"];
}

- (BOOL)pb_interrupted {
    return [[self valueForAdditionKey:@"pb_interrupted"] boolValue];
}

- (void)setAlias:(NSString *)alias {
    [self setValue:alias forAdditionKey:@"alias"];
}

- (NSString *)alias {
    return [self valueForAdditionKey:@"alias"];
}

- (void)setPb_needsReload:(BOOL)value {
    [self setValue:[NSNumber numberWithBool:value] forAdditionKey:@"pb_needsReload"];
}

- (BOOL)pb_needsReload {
    return [[self valueForAdditionKey:@"pb_needsReload"] boolValue];
}

@end
