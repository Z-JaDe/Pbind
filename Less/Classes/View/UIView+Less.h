//
//  UIView+Less.h
//  Less
//
//  Created by galen on 15/2/12.
//  Copyright (c) 2015年 galen. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LSClient.h"

//______________________________________________________________________________

@protocol LSViewLoadingDelegate <NSObject>

@optional
- (NSDictionary *)pullParamsForView:(UIView *)view;
- (void)view:(UIView *)view didChangePullStatus:(NSInteger)status;
- (void)view:(UIView *)view didFinishLoading:(LSResponse *)response handledError:(BOOL *)handledError;

@end

//______________________________________________________________________________

@interface UIView (Less)

@property (nonatomic, strong) NSString *plist;

@property (nonatomic, strong) NSArray *clients;
@property (nonatomic, strong) NSDictionary *actions;

@property (nonatomic, strong) NSString *client;
@property (nonatomic, strong) NSString *clientAction;
@property (nonatomic, strong) NSDictionary *clientParams;

@property (nonatomic, strong) NSString *href;
@property (nonatomic, strong, readonly, getter=hrefParams) NSDictionary *hrefParams;
@property (nonatomic, strong, readonly, getter=rootData) id rootData;
@property (nonatomic, strong) id data;
@property (nonatomic, assign) id<LSViewLoadingDelegate> loadingDelegate;
@property (nonatomic, assign) BOOL needsLoad;

@property (nonatomic, assign, readonly) BOOL pr_loading;
@property (nonatomic, assign) BOOL pr_interrupted;
@property (nonatomic, assign) BOOL showsLoadingCover;

@property (nonatomic, assign) void (^pr_lseparation)(void);
@property (nonatomic, assign) id (^pr_transformation)(id data, NSError *error);

- (void)setMappable:(BOOL)mappable forKeyPath:(NSString *)keyPath;
- (BOOL)mappableForKeyPath:(NSString *)keyPath;

- (void)setValue:(id)value forAdditionKey:(NSString *)key;
- (id)valueForAdditionKey:(NSString *)key;

- (void)setExpression:(NSString *)expression forKeyPath:(NSString *)keyPath;

- (UIViewController *)supercontroller;
- (id)superviewWithClass:(Class)clazz;

- (void)pr_clickHref:(NSString *)href;

- (void)pr_pullData;
- (void)pr_pullDataWithPreparation:(void (^)(void))preparation transformation:(id (^)(id data, NSError *error))transformation;
- (void)pr_repullData; // repull with previous `preparation' and `transformation'
- (void)pr_loadData:(id)data;
- (void)pr_cancelPull;

@end

UIKIT_EXTERN NSString *const LSViewDidStartLoadNotification;
UIKIT_EXTERN NSString *const LSViewDidFinishLoadNotification;
UIKIT_EXTERN NSString *const LSViewHasHandledLoadErrorKey;

UIKIT_EXTERN NSString *const LSViewDidClickHrefNotification;
UIKIT_EXTERN NSString *const LSViewHrefKey;

UIKIT_STATIC_INLINE NSString *LSHrefEncode(NSString *href)
{
    return (NSString *)
    CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                              (CFStringRef)href,
                                                              (CFStringRef)@"!$&'()*+,-./:;=?@_~%#[]",
                                                              NULL,
                                                              kCFStringEncodingUTF8));
}

UIKIT_STATIC_INLINE NSString *LSHrefDecode(NSString *href)
{
    return (__bridge_transfer NSString *)
    CFURLCreateStringByReplacingPercentEscapesUsingEncoding(NULL,
                                                            (__bridge CFStringRef)href,
                                                            CFSTR(""),
                                                            CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
}

UIKIT_STATIC_INLINE NSString *LSParameterJson(id object)
{
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:object options:0 error:nil];
    NSString *json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    json = LSHrefEncode(json);
    json = [json stringByReplacingOccurrencesOfString:@"&" withString:@"<amp>"];
    return json;
}

UIKIT_STATIC_INLINE id LSParameterDejson(NSString *json)
{
    NSString *decodedJson = LSHrefDecode(json);
    decodedJson = [decodedJson stringByReplacingOccurrencesOfString:@"<amp>" withString:@"&"];
    return [NSJSONSerialization JSONObjectWithData:[decodedJson dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
}

typedef void (*LSCallControllerFunc)(id, SEL, id);

UIKIT_STATIC_INLINE void LSViewClickHref(UIView *view, NSString *href)
{
    [view pr_clickHref:href];
}

