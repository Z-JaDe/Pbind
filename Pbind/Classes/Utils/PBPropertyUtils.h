//
//  PBPropertyUtils.h
//  Pods
//
//  Created by Galen Lin on 2016/10/28.
//
//

#import <Foundation/Foundation.h>

@interface PBPropertyUtils : NSObject

+ (void)setValue:(id)value forKey:(NSString *)key toObject:(id)object failure:(void (^)(void))failure;

@end
