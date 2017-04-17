//
//  Pbind.m
//  Pbind <https://github.com/wequick/Pbind>
//
//  Created by Galen Lin on 16/8/31.
//  Copyright (c) 2015-present, Wequick.net. All rights reserved.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "PBInline.h"
#import "UIView+Pbind.h"
#import "PBDataFetching.h"
#import "PBDataFetcher.h"
#import "PBClientMapper.h"
#import "PBViewController.h"

@implementation Pbind : NSObject

static const CGFloat kDefaultSketchWidth = 320.f;
static CGFloat kValueScale = 0;
static NSMutableArray *kResourcesBundles = nil;

+ (void)setSketchWidth:(CGFloat)sketchWidth {
    kValueScale = [UIScreen mainScreen].bounds.size.width / sketchWidth;
}

+ (CGFloat)valueScale {
    if (kValueScale == 0) {
        kValueScale = [UIScreen mainScreen].bounds.size.width / kDefaultSketchWidth;
    }
    return kValueScale;
}

+ (void)addResourcesBundle:(NSBundle *)bundle {
    if (kResourcesBundles == nil) {
        kResourcesBundles = [[NSMutableArray alloc] init];
        [kResourcesBundles addObject:[NSBundle mainBundle]];
    }
    
    if ([kResourcesBundles indexOfObject:bundle] != NSNotFound) {
        return;
    }
    [kResourcesBundles insertObject:bundle atIndex:0];
}

+ (NSArray<NSBundle *> *)allResourcesBundles {
    if (kResourcesBundles == nil) {
        kResourcesBundles = [[NSMutableArray alloc] init];
        [kResourcesBundles addObject:[NSBundle mainBundle]];
    }
    return kResourcesBundles;
}

+ (void)enumerateControllersUsingBlock:(void (^)(UIViewController *controller))block {
    UIViewController *rootViewController = [[UIApplication sharedApplication].delegate window].rootViewController;
    [self enumerateControllersUsingBlock:block withController:rootViewController];
}

+ (void)enumerateControllersUsingBlock:(void (^)(UIViewController *controller))block withController:(UIViewController *)controller {
    
    block(controller);
    
    UIViewController *presentedController = [controller presentedViewController];
    if (presentedController != nil) {
        [self enumerateControllersUsingBlock:block withController:presentedController];
    }
    
    if ([controller isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (id) controller;
        for (UIViewController *vc in nav.viewControllers) {
            [self enumerateControllersUsingBlock:block withController:vc];
        }
    } else if ([controller isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tc = (id) controller;
        for (UIViewController *vc in tc.viewControllers) {
            [self enumerateControllersUsingBlock:block withController:vc];
        }
    }
}

+ (void)enumerateSubviewsForView:(UIView *)view usingBlock:(void (^)(UIView *subview, BOOL *stop))block {
    BOOL stop;
    [self _enumerateSubviewsForView:view stop:&stop usingBlock:block];
}

+ (void)_enumerateSubviewsForView:(UIView *)view stop:(BOOL *)stop usingBlock:(void (^)(UIView *subview, BOOL *stop))block {
    block(view, stop);
    if (*stop) {
        return;
    }
    
    for (UIView *subview in view.subviews) {
        [self _enumerateSubviewsForView:subview stop:stop usingBlock:block];
        if (*stop) {
            return;
        }
    }
}

+ (void)reloadViewsOnPlistUpdate:(NSString *)plist {
    // Reload the specify views that using the plist.
    NSArray *pathComponents = [plist componentsSeparatedByString:@"/"];
    NSString *changedPlist = [[pathComponents lastObject] stringByReplacingOccurrencesOfString:@".plist" withString:@""];
    [self enumerateControllersUsingBlock:^(UIViewController *controller) {
        NSString *usingPlist = controller.view.plist;
        if (usingPlist == nil) {
            return;
        }
        if ([usingPlist isEqualToString:changedPlist]) {
            [controller.view pb_reloadPlist];
            return;
        }
        
        // Check the layout configured in the plist
        [self enumerateSubviewsForView:controller.view usingBlock:^(UIView *subview, BOOL *stop) {
            if (subview.pb_layoutName == nil) {
                return;
            }
            if ([subview.pb_layoutName isEqualToString:changedPlist]) {
                [controller.view pb_reloadPlist];
                return;
            }
        }];
    }];
}

+ (void)reloadViewsOnAPIUpdate:(NSString *)action {
    // Reload the specify views that using the API.
    UIViewController *topController = PBTopController();
    [self enumerateControllersUsingBlock:^(UIViewController *controller) {
        __block PBDataFetcher *fetcher = nil;
        [self enumerateSubviewsForView:controller.view usingBlock:^(UIView *subview, BOOL *stop) {
            if (![subview conformsToProtocol:@protocol(PBDataFetching)]) {
                return;
            }
            
            UIView<PBDataFetching> *fetchingView = (id) subview;
            NSArray *clients = [[fetchingView fetcher] clientMappers];
            for (PBClientMapper *client in clients) {
                if ([client.action isEqualToString:action] ||
                    [client.action isEqualToString:[NSString stringWithFormat:@"/%@", action]]) {
                    fetcher = [fetchingView fetcher];
                    *stop = YES;
                    break;
                }
            }
        }];
        
        if (fetcher == nil) {
            return;
        }
        
        BOOL lazyReload = (controller != topController && [controller isKindOfClass:[PBViewController class]]);
        if (lazyReload) {
            [(PBViewController *)controller setNeedsReloadData];
        } else {
            [fetcher fetchData];
        }
    }];
}

@end
