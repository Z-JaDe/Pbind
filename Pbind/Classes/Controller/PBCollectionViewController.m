//
//  PBCollectionViewController.m
//  Pods
//
//  Created by Galen Lin on 2016/10/18.
//
//

#import "PBCollectionViewController.h"
#import "UIView+Pbind.h"

@interface UIView (Private)

- (void)pb_setInitialData:(id)data;

@end

@interface PBCollectionViewController ()

@end

@implementation PBCollectionViewController

- (void)viewDidLoad {
    _collectionView = [[PBCollectionView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    _collectionView.delegate = self;
    _collectionView.dataSource = self;
    _collectionView.backgroundColor = [UIColor whiteColor];
    self.view = _collectionView;
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [_collectionView pb_setInitialData:self.data];
    [_collectionView pb_reloadPlist];
}

#pragma mark - Stub dataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return -1;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

@end
