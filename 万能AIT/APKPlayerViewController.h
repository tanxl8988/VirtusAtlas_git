//
//  APKPlayerViewController.h
//  万能AIT
//
//  Created by mac on 2020/8/8.
//  Copyright © 2020 APK. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface APKPlayerViewController : UIViewController
@property (nonatomic,retain) NSURL *URL;
@property (nonatomic,assign) BOOL videoIsLocal;
- (void)configureWithURLs:(NSArray *)URLs currentIndex:(NSInteger)currentIndex fileArray:(NSArray *)fileArray;


@end

NS_ASSUME_NONNULL_END
