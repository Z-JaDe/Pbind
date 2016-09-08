//
//  LSExampleClient.m
//  Less
//
//  Created by Galen Lin on 16/9/7.
//  Copyright © 2016年 galenlin. All rights reserved.
//

#import "LSExampleClient.h"

@implementation LSExampleClient

- (void)loadRequest:(LSRequest *)request success:(void (^)(id))success failure:(void (^)(NSError *))failure
{
    NSString *action = request.action;
    if ([action isEqualToString:@"GetGroupInfo"]) {
        id data = @{@"groupName": @"My Group",
                    @"memberNum": @3,
                    @"notification": @"Some notification",
                    @"faceURL:": @"https://placehold.it/165/78b8fc/f0f0f0/?text=PR"};
        success(data);
    } else if ([action isEqualToString:@"GetGroupMembers"]) {
        NSMutableArray *members = [NSMutableArray arrayWithCapacity:8];
        for (int i = 0; i < 8; i++) {
            NSDictionary *member = @{@"nameCard": [NSString stringWithFormat:@"Hello%i", i],
                                     @"customInfo": @{
                                             @"avatar": [NSString stringWithFormat:@"https://placehold.it/165/78b8fc/f0f0f0/?text=%i", i]
                                             }};
            [members addObject:member];
        }
        id data = @{@"list": members, @"nickname": @"My nickname"};
        success(data);
    } else if ([action isEqualToString:@"QuitGroup"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            success(nil);
        });
    }
}

@end
