//
//  PBRowAction.m
//  Pbind <https://github.com/wequick/Pbind>
//
//  Created by Galen Lin on 22/12/2016.
//  Copyright (c) 2015-present, Wequick.net. All rights reserved.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "PBRowAction.h"
#import "PBTableView.h"
#import "UIView+Pbind.h"
#import "PBArray.h"
#import "PBRowMapping.h"

@implementation PBRowAction

@pbactions(@"addRow", @"deleteRow", @"updateRow")
- (void)run:(PBActionState *)state {
    if (state.context == nil) {
        return;
    }
    
    if ([NSThread isMainThread]) {
        [self runOnMainThread:state];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self runOnMainThread:state];
        });
    }
}

- (void)runOnMainThread:(PBActionState *)state {
    UIView<PBRowMapping> *mappingView = [self mappableParentViewOfSubview:state.context];
    if (mappingView == nil) {
        return;
    }
    
    if ([self.type isEqualToString:@"addRow"]) {
        if (state.data == nil) {
            return;
        }
        
        [mappingView.rowDataSource addRowData:state.data];
    } else if ([self.type isEqualToString:@"deleteRow"]) {
        if (state.status != PBResponseStatusNoContent) {
            return;
        }
        
        NSIndexPath *indexPath = mappingView.editingIndexPath ?: state.params[@"indexPath"];
        if (indexPath == nil) {
            indexPath = [self indexPathForSubview:state.context inOwnerView:mappingView];
            if (indexPath == nil) {
                return;
            }
        }
        [mappingView.rowDataSource deleteRowDataAtIndexPath:indexPath];
    } else if ([self.type isEqualToString:@"updateRow"]) {
        NSIndexPath *indexPath = mappingView.editingIndexPath ?: state.params[@"indexPath"];
        if (indexPath == nil) {
            indexPath = [self indexPathForSubview:state.context inOwnerView:mappingView];
            if (indexPath == nil) {
                return;
            }
        }
        [mappingView.rowDataSource updateRowDataAtIndexPath:indexPath];
    }
    
    if ([self hasNext:@"done"]) {
        // FIXME: Add completion block on row action
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.25f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self dispatchNext:@"done"];
        });
    }
}

- (UIView<PBRowMapping> *)mappableParentViewOfSubview:(UIView *)view {
    if (view == nil) {
        return nil;
    }
    
    if ([view conformsToProtocol:@protocol(PBRowMapping)]) {
        return (id) view;
    }
    
    return [self mappableParentViewOfSubview:view.superview];
}

- (NSIndexPath *)indexPathForSubview:(UIView *)subview inOwnerView:(UIView *)ownerView {
    if ([ownerView isKindOfClass:[UICollectionView class]]) {
        UICollectionViewCell *cell = [subview superviewWithClass:[UICollectionViewCell class]];
        if (cell == nil) {
            return nil;
        }
        return [(UICollectionView *)ownerView indexPathForCell:cell];
    } else if ([ownerView isKindOfClass:[UITableView class]]) {
        UITableViewCell *cell = [subview superviewWithClass:[UITableViewCell class]];
        if (cell == nil) {
            return nil;
        }
        return [(UITableView *)ownerView indexPathForCell:cell];
    }
    return nil;
}

@end
