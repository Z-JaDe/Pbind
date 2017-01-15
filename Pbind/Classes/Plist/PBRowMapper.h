//
//  PBRowMapper.h
//  Pbind <https://github.com/wequick/Pbind>
//
//  Created by galen on 15/2/17.
//  Copyright (c) 2015-present, Wequick.net. All rights reserved.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <Foundation/Foundation.h>
#import "PBMapper.h"
#import "PBLayoutMapper.h"
#import "PBRowActionMapper.h"

@class PBRowDataSource;

//______________________________________________________________________________
// PBRowMapperDelegate
@class PBRowMapper;
@protocol PBRowMapperDelegate <NSObject>

- (void)rowMapper:(PBRowMapper *)mapper didChangeValue:(id)value forKey:(NSString *)key;

@end

//______________________________________________________________________________

typedef NS_ENUM(NSUInteger, PBRowFloating)
{
    PBRowFloatingNone = 0,
    PBRowFloatingTop,       // :ft
    PBRowFloatingLeft,      // :fl
    PBRowFloatingBottom,    // :fb
    PBRowFloatingRight      // :fr
};

@interface PBRowMapper : PBMapper
{
    struct {
        unsigned int mapping:1;
        unsigned int heightExpressive:1;
        unsigned int hiddenExpressive:1;
    } _pbFlags;
}

@property (nonatomic, strong) NSString *nib;
@property (nonatomic, strong) NSString *clazz;
@property (nonatomic, strong) NSString *id;
@property (nonatomic, assign) CGFloat estimatedHeight;
@property (nonatomic, assign) CGFloat height;
@property (nonatomic, assign) CGSize size;
@property (nonatomic, assign) BOOL hidden;
@property (nonatomic, assign) UIEdgeInsets margin;
@property (nonatomic, assign) UIEdgeInsets padding;

@property (nonatomic, assign) UITableViewCellStyle style;

@property (nonatomic, assign) PBRowFloating floating;

@property (nonatomic, strong) NSString *layout;
@property (nonatomic, strong) PBLayoutMapper *layoutMapper;

@property (nonatomic, assign) Class viewClass;

@property (nonatomic, assign) id<PBRowMapperDelegate> delegate;

/**
 The actions for row, each value is a dictionary which parse as `PBActionMapper'.
 
 @discussion accept keys:
 
 - willSelect   : the cell willSelect action
 - select       : the cell didSelect action
 - willDeselect : the cell willDeselect action
 - deselect     : the cell didDeselect action
 - delete       : the editing(swipe-to-left) cell delete button action
 - edits        : the editing(swipe-to-left) cell custom edit actions
 */
@property (nonatomic, strong) NSDictionary *actions;

@property (nonatomic, strong) PBActionMapper *willSelectActionMapper;
@property (nonatomic, strong) PBActionMapper *selectActionMapper;
@property (nonatomic, strong) PBActionMapper *willDeselectActionMapper;
@property (nonatomic, strong) PBActionMapper *deselectActionMapper;

/**
 The action mappers which map to UITableViewRowAction for editing UITableViewCell.
 
 @discussion If the `actions' were specified, use it, otherwise use `deleteAction' if there was.
 */
@property (nonatomic, strong) NSArray<PBRowActionMapper *> *editActionMappers;

/**
 Whether the height is defined by an expression.
 */
@property (nonatomic, assign, readonly, getter=isHeightExpressive) BOOL heightExpressive;

- (BOOL)hiddenForView:(id)view withData:(id)data;
- (CGFloat)heightForView:(id)view withData:(id)data;

- (CGFloat)heightForData:(id)data withRowDataSource:(PBRowDataSource *)dataSource indexPath:(NSIndexPath *)indexPath;
- (CGFloat)heightForData:(id)data;

- (UIView *)createView;

@end
