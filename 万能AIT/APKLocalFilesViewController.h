//
//  APKLocalFilesViewController.h
//  万能AIT
//
//  Created by Mac on 17/5/9.
//  Copyright © 2017年 APK. All rights reserved.
//

#import "APKBaseViewController.h"
#import "APKDVRFile.h"

@interface APKLocalFilesViewController : APKBaseViewController

@property (nonatomic) APKFileType fileType;
@property (copy,nonatomic) void (^updateLocalAlbumCoverBlock)(APKFileType fileType);

@end
