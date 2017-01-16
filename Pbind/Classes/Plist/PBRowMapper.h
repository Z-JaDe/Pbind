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

/**
 The PBRowMapper is one of the base components of Pbind.
 
 @dicussion It provides the ability of configuring row elements like:
 
 - UITableViewCell
 - UICollectionViewCell
 
 for PBTableView, PBCollectionView and PBScrollView.
 */
@interface PBRowMapper : PBMapper
{
    struct {
        unsigned int mapping:1;
        unsigned int heightExpressive:1;
        unsigned int hiddenExpressive:1;
    } _pbFlags;
}

#pragma mark - Creating
///=============================================================================
/// @name Creating
///=============================================================================

/** The class name of the view in the row. Default is UITableViewCell */
@property (nonatomic, strong) NSString *clazz;

/** The xib file name for the view in the row. Default to `clazz` */
@property (nonatomic, strong) NSString *nib;

/**
 The style for the cell in the row.
 
 @discussion If set, the default `clazz` turns to be PBTalbViewCell.
 */
@property (nonatomic, assign) UITableViewCellStyle style;

/**
 The identifier for the view in the row.
 
 @discussion This property is only for PBTableView and PBCollectionView
 */
@property (nonatomic, strong) NSString *id;

/**
 The layout file to create subviews and add to the view in the row.
 
 @discussion The layout file with Plist will be parsed by PBLayoutMapper.
 */
@property (nonatomic, strong) NSString *layout;

#pragma mark - Styling
///=============================================================================
/// @name Styling
///=============================================================================

/**
 The height for the row. Default is -1 (auto-height).
 */
@property (nonatomic, assign) CGFloat height;

/**
 The estimated height for the row. Default is -1 (do not estimated).
 
 @discussion This property is only for PBTableView and PBCollectionView.
 If the `height` was explicitly set as `:auto`(-1) then default to 44.
 */
@property (nonatomic, assign) CGFloat estimatedHeight;

/**
 The size for the item(UICollectionViewCell) in the row.
 
 @discussion This property if only for PBCollectionView.
 */
@property (nonatomic, assign) CGSize size;

/**
 Whether hides the row. Default is NO.
 
 @discussion For PBTableView and PBCollection, this will cause the delegate method
 `heightForCell` returns 0. For PBScrollView we just set adjust the frame of the view in the row.
 */
@property (nonatomic, assign) BOOL hidden;

/**
 The outer margin for the row.
 
 @discussion This property is only for PBScrollView.
 The function of margin is same as the CSS margin.
 */
@property (nonatomic, assign) UIEdgeInsets margin;

/**
 The inner margin for the row.
 
 @discussion This property is only for PBScrollView.
 The function of padding is same as the CSS padding.
 */
@property (nonatomic, assign) UIEdgeInsets padding;

/**
 The floating style for the row.
 
 @discussion This property is only for PBScrollView.
 */
@property (nonatomic, assign) PBRowFloating floating;

#pragma mark - Behavior
///=============================================================================
/// @name Behavior
///=============================================================================

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

#pragma mark - Caching
///=============================================================================
/// @name Caching
///=============================================================================

/** The mapper created from `layout` */
@property (nonatomic, strong) PBLayoutMapper *layoutMapper;

/** The class initialized from `clazz` */
@property (nonatomic, assign) Class viewClass;

/** The mapper created from `actions`.willSelect */
@property (nonatomic, strong) PBActionMapper *willSelectActionMapper;

/** The mapper created from `actions`.select */
@property (nonatomic, strong) PBActionMapper *selectActionMapper;

/** The mapper created from `actions`.willDeselect */
@property (nonatomic, strong) PBActionMapper *willDeselectActionMapper;

/** The mapper created from `actions`.deselect */
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
