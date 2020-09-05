//
//  APKAboatViewController.m
//  YunZhiHui2
//
//  Created by Cong's Jobs on 15/12/3.
//  Copyright © 2015年 Apical. All rights reserved.
//

#import "APKAboatViewController.h"
#import "APKAlertTool.h"
#import "APKDVRCommandFactory.h"

@interface APKAboatViewController ()

@property (weak, nonatomic) IBOutlet UILabel *versionLabel;
@property (weak, nonatomic) IBOutlet UILabel *firmwareVersionLabel;

@end

@implementation APKAboatViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
   
    self.navigationItem.title = NSLocalizedString(@"关于", nil);
    NSString *app_Name = NSLocalizedString(@"Virtus Atlas", nil);
    NSString *appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    self.versionLabel.text = [NSString stringWithFormat:@"%@-V %@",app_Name,@"1.4"];
    
    if (self.firmwareVersion) {
        
        self.firmwareVersionLabel.text = self.firmwareVersion;
    }
}


@end









