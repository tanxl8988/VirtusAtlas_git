//
//  MStarUpgradeHandler.h
//  RoavCam
//
//  Created by ocean on 2018/2/2.
//  Copyright © 2018年 Oceanwing. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MBProgressHUD.h"

typedef void (^MStarUpgradeResult)(BOOL success, NSString * errorInfo);

typedef void (^MStarUpgradeProgress)(float upgradeUploadProgress);

typedef void (^completionHandle)();


@interface MStarUpgradeHandler : NSObject

@property (strong, nonatomic) MStarUpgradeResult resultCB;
@property (strong, nonatomic) MStarUpgradeProgress progressCB;
@property (strong, nonatomic) completionHandle completion;


-(void) threadSafeUpgradeWithFilePath : (NSString *) path cb : (MStarUpgradeResult)cb progress : (MStarUpgradeProgress) progressCb completionHandle:(completionHandle)completion;

-(void) triggerRestartDevice;
//-(void) startUpgradeWithFilePath : (NSString *) path cb : (MStarUpgradeResult)cb;

@end
