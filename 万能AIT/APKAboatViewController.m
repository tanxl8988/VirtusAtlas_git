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
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (nonatomic,assign) BOOL isDeveloperModel;

@end

@implementation APKAboatViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
   
    self.navigationItem.title = NSLocalizedString(@"关于", nil);
    NSString *app_Name = NSLocalizedString(@"Virtus Atlas", nil);
    NSString *appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    self.versionLabel.text = [NSString stringWithFormat:@"%@-V %@",app_Name,appVersion];
    
    if (self.firmwareVersion) {
        
        self.firmwareVersionLabel.text = self.firmwareVersion;
        self.firmwareVersionLabel.textColor = [UIColor blackColor];
    }
    
    NSNumber *value = [[NSUserDefaults standardUserDefaults] objectForKey:@"APKDEVELOPERMODEL"];
    _isDeveloperModel = (value == @YES) ? YES : NO;
    
    self.view.backgroundColor = _isDeveloperModel ? [UIColor lightGrayColor] : [UIColor whiteColor];
    
    self.imageView.userInteractionEnabled = YES;
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapView:)];
    tap.numberOfTapsRequired = 3;
    [self.imageView addGestureRecognizer:tap];
}

-(void)tapView:(UITapGestureRecognizer *)sender{
    
    _isDeveloperModel = !_isDeveloperModel;
    
    if (_isDeveloperModel) {
        [[NSUserDefaults standardUserDefaults] setObject:@YES forKey:@"APKDEVELOPERMODEL"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        self.view.backgroundColor = [UIColor lightGrayColor];
    }else{
        [[NSUserDefaults standardUserDefaults] setObject:@NO forKey:@"APKDEVELOPERMODEL"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        self.view.backgroundColor = [UIColor whiteColor];
    }
}
@end









