//
//  LBLocalImageVC.m
//  test
//
//  Created by dengweihao on 2017/12/26.
//  Copyright © 2017年 dengweihao. All rights reserved.
//

#import "LBLocalImageVC.h"
#import "UIView+LBFrame.h"
#import "LBPhotoBrowserManager.h"
#import "UIImage+LBDecoder.h"
#import "LBAlbumManager.h"

#import <AssetsLibrary/AssetsLibrary.h>
#import <MobileCoreServices/MobileCoreServices.h>


#define MAX_COUNT 9
#define LB_WEAK_SELF __weak typeof(self)wself = self

@interface LBLocalImageView : UIImageView
@property (nonatomic , strong)NSData *gifData;
@end

@implementation LBLocalImageView
- (instancetype)init
{
    self = [super init];
    if (self) {
        self.contentMode = UIViewContentModeScaleAspectFill;
        self.clipsToBounds = YES;
        self.userInteractionEnabled = YES;
    }
    return self;
}

@end;

@interface LBLocalImageVC ()
@property (nonatomic , strong)NSMutableArray *frames;
@property (nonatomic , weak)UIButton *addBtn;
@property (nonatomic , strong)NSMutableArray *imageViews;

@end

@implementation LBLocalImageVC

- (void)dealloc {
    LBPhotoBrowserLog(@"%@ 销毁了",NSStringFromClass([self class]));
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.frames = @[].mutableCopy;
    self.imageViews = @[].mutableCopy;
    LB_WEAK_SELF;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        int column = 3;
        CGFloat itemWidth = ([UIScreen mainScreen].bounds.size.width - 2 * 10) / 3;
        CGFloat itemHeight = itemWidth;
        for (int i = 0; i < MAX_COUNT; i++) {
            CGFloat x = (i % column) * (10 + itemWidth) ;
            CGFloat y = (i / column) * (10 + itemHeight);
            CGRect frame = CGRectMake(x,100 + y, itemWidth, itemHeight);
            [wself.frames addObject:[NSValue valueWithCGRect:frame]];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            UIButton *addBtn = [[UIButton alloc]initWithFrame:[wself.frames.firstObject CGRectValue]];
            addBtn.backgroundColor = [UIColor lightGrayColor];
            [addBtn setTitle:@"添加" forState:UIControlStateNormal];
            [addBtn addTarget:self action:@selector(getImageFromIpc) forControlEvents:UIControlEventTouchDown];
            [wself.view addSubview:addBtn];
            wself.addBtn = addBtn;
        });
    });
}


- (void)getImageFromIpc
{
    int maxCount = MAX_COUNT - (int)self.imageViews.count;
    if (maxCount == 0) {
        return;
    }
    [[LBAlbumManager shareManager] selectImagesFromAlbumShow:^(UIViewController *needToPresentVC) {
        [self presentViewController:needToPresentVC animated:YES completion:nil];
    } imageModels:^(NSArray<LBImageAlbumModel *> *imageModels) {
        [self refreshUIWithImageModels:imageModels];
    } maxCount:maxCount];
}

- (void)refreshUIWithImageModels:(NSArray<LBImageAlbumModel *> *)imageModels {
    for (int i = 0; i < imageModels.count; i++) {
        LBImageAlbumModel *model = imageModels[i];
        LBLocalImageView *imageView = [[LBLocalImageView alloc]init];
        if (model.isGif) {
            imageView.gifData = model.gifImageData;
        }
        imageView.image = model.image;
        imageView.tag = self.imageViews.count;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(imageClick:)];
        [imageView addGestureRecognizer:tap];
        [self.view addSubview:imageView];
        CGRect frame = [self.frames[self.imageViews.count] CGRectValue];
        imageView.frame = frame;
        [self.imageViews addObject:imageView];
    }
    
    if (self.imageViews.count == MAX_COUNT) {
        self.addBtn.hidden = YES;
        return;
    }
    self.addBtn.frame = [self.frames[self.imageViews.count] CGRectValue];
}


- (void)imageClick:(UITapGestureRecognizer *)tap {
    NSMutableArray *items = @[].mutableCopy;
    for (LBLocalImageView *imageView in self.imageViews) {
        LBPhotoLocalItem *item = [[LBPhotoLocalItem alloc]initWithImage:imageView.image frame:imageView.frame gifData:imageView.gifData];
        [items addObject:item];
    }
    weak_self;
    // 这里只要你开心 可以无限addBlock
    [[[[[LBPhotoBrowserManager defaultManager] showImageWithLocalItems:items selectedIndex:tap.view.tag fromImageViewSuperView:self.view] addLongPressShowTitles:@[@"保存图片",@"识别二维码",@"取消"]] addTitleClickCallbackBlock:^(UIImage *image, NSIndexPath *deleIndexPath, NSString *title, BOOL isGif, NSData *gifImageData) {
        LBPhotoBrowserLog(@"%@",title);
    }]addPhotoBrowserDeleteItemBlock:^(NSIndexPath *indexPath, UIImage *image) {
        // 刷新UI
        [wself refreshUIWithIndex:indexPath.row];
    }].lowGifMemory = YES;
}

- (void)refreshUIWithIndex:(NSInteger)index {
    UIImageView *deleImageView = self.imageViews[index];
    deleImageView.hidden = YES;
    for (int i = 0; i < self.imageViews.count; i++) {
        if (i <= index) continue;
        UIImageView *imageView = self.imageViews[i];
        CGRect frame = CGRectZero;
        UIImageView *imageViewPrevious = self.imageViews[i - 1];
        frame = imageViewPrevious.frame;
        imageView.tag = imageView.tag - 1;
        [UIView animateWithDuration:0.25 animations:^{
            imageView.frame = frame;
        }];
    }
    NSValue *value = self.frames[self.imageViews.count - 1];
    [UIView animateWithDuration:0.25 animations:^{
        self.addBtn.frame = [value CGRectValue];
    }];
    [self.imageViews removeObjectAtIndex:index];
    [deleImageView removeFromSuperview];
    if (self.imageViews.count < MAX_COUNT) {
        self.addBtn.hidden = NO;
    }
}
@end
