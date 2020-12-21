//
//  APKPlayerViewController.m
//  万能AIT
//
//  Created by mac on 2020/8/8.
//  Copyright © 2020 APK. All rights reserved.
//

#import "APKPlayerViewController.h"
#import "MobileVLCKit/VLCMediaPlayer.h"
#import "APKAlertTool.h"
#import <MapKit/MapKit.h>
#import "APKLocalFile.h"
#import "APKHandleGpsInfoTool.h"
#import "APKLocalFile.h"


@interface APKPlayerViewController ()<VLCMediaPlayerDelegate,VLCMediaDelegate,MKMapViewDelegate, CLLocationManagerDelegate>
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UIView *playerView;
@property (weak, nonatomic) IBOutlet UIButton *previousButton;
@property (weak, nonatomic) IBOutlet UIButton *nextButton;
@property (weak, nonatomic) IBOutlet UILabel *progressLabel;
@property (weak, nonatomic) IBOutlet UILabel *durationLabel;
@property (weak, nonatomic) IBOutlet UISlider *progressSlider;
@property (weak, nonatomic) IBOutlet UIButton *playButton;
@property (weak, nonatomic) IBOutlet UIButton *pauseButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *flower;
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (strong,nonatomic) VLCMediaPlayer *player;
@property (nonatomic) NSInteger currentIndex;
@property (strong,nonatomic) NSArray *URLs;
@property (strong,nonatomic) VLCMediaPlayer *mediaPlayer;
@property (nonatomic) BOOL haveLoadVideoDuration;
@property (nonatomic) BOOL isStopForLoadNewVideo;
@property (nonatomic,assign) int lastPLayTime;
@property (assign) BOOL isPausing;
@property (nonatomic,retain) NSArray *locationArray;
@property (nonatomic,retain) NSArray *localFileArr;
@property (nonatomic,retain) MKPolyline *baseLine;
@property (nonatomic,retain) NSTimer *time;
@property (nonatomic,retain) MKPolyline *lastVisibleLine;
@property (nonatomic,retain) MKPolyline *visibleLine;
@property (nonatomic,assign) BOOL isFirstShowVisibleLine;
@property (nonatomic,assign) BOOL isRemoteVideo;
@property (nonatomic,retain) CLLocationManager *locationManager;
@property (nonatomic,retain) NSURL *localFileURL;
@property (nonatomic, strong) CLLocationManager *localManager;
@property (nonatomic,assign) NSInteger passedPointCount;
@property (nonatomic,assign) CLLocationCoordinate2D coords;
@property (nonatomic,assign) float animationDurationTime;
@property (nonatomic,assign) float durationTime;
@property (nonatomic,assign) float sliderFinishTime;
@property (nonatomic,assign) BOOL playFinished;
@property (nonatomic,retain) MKPointAnnotation *annotation;
@property (strong,nonatomic) dispatch_source_t heartBeatTimer;
@property (nonatomic,assign) int annotationNum;
@property (nonatomic,assign) BOOL HaveGPSData;

@end

@implementation APKPlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //初始化地图
      [self initWithMapView];
      //初始化定位服务管理对象
      [self initWithLocationManager];
      [_locationManager startUpdatingLocation];
    
    [self.progressSlider setThumbImage:[UIImage imageNamed:@"videoPlayer_sliderBar"] forState:UIControlStateNormal];
    [self.progressSlider setThumbImage:[UIImage imageNamed:@"videoPlayer_sliderBar"] forState:UIControlStateSelected];
    
    [self updateSwitchVideoButtons];
    
    self.mediaPlayer.delegate = self;
    [self.mediaPlayer addObserver:self forKeyPath:@"state" options:NSKeyValueObservingOptionNew context:nil];
    
    if ([self.URLs.firstObject class] == [NSURL class]) {
          [self.mapView removeFromSuperview];
          self.playerView.center = self.view.center;
      }
    
    _HaveGPSData = NO;
    
    if (self.URLs.count > self.currentIndex){
        [self getFileName];
        [self loadNewVideo];
    }
        
    self.isFirstShowVisibleLine = YES;
    
    // Do any additional setup after loading the view from its nib.
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self.mediaPlayer stop];

    [self.mediaPlayer removeObserver:self forKeyPath:@"state"];
    
//    if (self.heartBeatTimer) {
//        dispatch_cancel(self.heartBeatTimer);
//    }
    
}


-(void)getFileName
{
    NSString *fileName = @"";
    
    if ([self.URLs.firstObject class] == [NSURL class]){
        NSURL *url = self.URLs[self.currentIndex];
        fileName = [url.absoluteString lastPathComponent];
    }else{
        APKLocalFile *file = self.localFileArr[self.currentIndex];
        fileName = file.info.name;
    }
    self.titleLabel.text = fileName;
}

- (void)initWithMapView
{
    _mapView.delegate = self;
    // 是否显示比例尺（iOS9.0）
    self.mapView.showsScale = YES;
    // 是否显示交通（iOS9.0）
    self.mapView.showsTraffic = YES;
    // 是否显示建筑物
    self.mapView.showsBuildings = YES;
}

- (void)initWithLocationManager
{
    //初始化定位服务管理对象
    _locationManager = [[CLLocationManager alloc] init];
    _locationManager.delegate = self;
//    [_locationManager requestAlwaysAuthorization];
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0)
    {
        // requestAlwaysAuthorization 永久授权
        // requestWhenInUseAuthorization 使用期间授权
        [_locationManager requestAlwaysAuthorization];
    }
    //设置精确度
    _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    //设置设备移动后获取位置信息的最小距离。单位为米
    _locationManager.distanceFilter = 10.0f;
    
}



- (void)configureWithURLs:(NSArray *)URLs currentIndex:(NSInteger)currentIndex fileArray:(NSArray *)fileArray{

    self.URLs = URLs;
    self.currentIndex = currentIndex;
    self.localFileArr = fileArray;
}

- (IBAction)back:(UIButton *)sender {
    
    if (self.mediaPlayer.state != VLCMediaPlayerStateStopped) {
          
          [self.mediaPlayer stop];
      }

      [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    
    if ([keyPath isEqualToString:@"state"]) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            
            VLCMediaPlayerState state = [change[@"new"] integerValue];
            [weakSelf updatePlayPauseButtonWithState:state];
            [weakSelf updateTipsLabelWithState:state];
            [weakSelf updateFlowerWithState:state];
            [weakSelf updateProgressInfoWithState:state];
//            NSLog(@"=============new state:%ld",(long)state);
            
            if (state == VLCMediaPlayerStateStopped && weakSelf.isStopForLoadNewVideo) {
                
                weakSelf.isStopForLoadNewVideo = NO;
                [weakSelf loadNewVideo];
            }
        });
    }
}

- (void)loadNewVideo{
    
    if (self.mediaPlayer.state != VLCMediaPlayerStateStopped) {
        
        self.isStopForLoadNewVideo = YES;
        self.playFinished = NO;
        [self.mediaPlayer stop];
        return;
    }
    
    self.haveLoadVideoDuration = NO;
    NSURL *url = nil;
    if ([self.URLs.firstObject class] == [PHAsset class]) {

        if (!self.localFileURL || self.localFileURL == nil) {
            [self getVideoURL:self.URLs[self.currentIndex]];
            return;
        }else
            url = self.localFileURL;

    }else if ([self.URLs.firstObject class] == [NSURL class])
        url = self.URLs[self.currentIndex];
    
    VLCMedia *media = [VLCMedia mediaWithURL:url];
    media.delegate = self;
    [self.mediaPlayer setMedia:media];
    [self.mediaPlayer play];
}

-(void)getVideoURL:(PHAsset *)asset
{
    __weak typeof(self) weakSelf = self;
    PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
    options.version = PHImageRequestOptionsVersionCurrent;
    options.deliveryMode = PHVideoRequestOptionsDeliveryModeAutomatic;
    
    PHImageManager *manager = [PHImageManager defaultManager];
    [manager requestAVAssetForVideo:asset
                            options:options
                      resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
                          // asset 类型为 AVURLAsset  为此资源的fileURL
                          // <AVURLAsset: 0x283386e60, URL = file:///var/mobile/Media/DCIM/100APPLE/IMG_0049.MOV>
                          AVURLAsset *urlAsset = (AVURLAsset *)asset;
                          // 视频数据
                          NSURL *url = urlAsset.URL;
                          weakSelf.localFileURL = url;
                          [weakSelf loadNewVideo];
                          NSData *vedioData = [NSData dataWithContentsOfURL:urlAsset.URL];
                          NSLog(@"%@",vedioData);
    }];
}



-(void)drawLine
{
    
    APKLocalFile *file = self.localFileArr[self.currentIndex];
    
    self.locationArray = [APKHandleGpsInfoTool transformGpsInfoFromStringToArr:file.info.gpsStr];
    
    if (self.baseLine) {
        [self.mapView removeOverlay:self.baseLine];
    }
    
//         NSArray *locationArray = @[@[@"37.93563",@"116.377358"],@[@"37.935564",@"116.376414"],@[@"37.935646",@"116.376037"],@[@"37.93586",@"116.375791"],@[@"37.93586",@"116.375791"],@[@"37.937983",@"116.37474"],@[@"37.937616",@"116.3746"],@[@"37.937888",@"116.376971"],@[@"37.937855",@"116.377047"],@[@"37.937172",@"116.377132"],@[@"37.937604",@"116.377218"],@[@"37.937489",@"116.377132"],@[@"37.93614",@"116.377283"],@[@"37.935622",@"116.377347"]];
    
//        self.locationArray = locationArray;
    
    NSArray *firstLocationArr = self.locationArray.firstObject;
    NSArray *lastLocationArr = self.locationArray.lastObject;
    if ((!firstLocationArr || [firstLocationArr.firstObject isEqualToString:@""]) && (!lastLocationArr || [lastLocationArr.firstObject isEqualToString:@""])) {
        [APKAlertTool showAlertInViewController:self title:nil message:NSLocalizedString(@"地图无法显示", nil) confirmHandler:nil];
        return;
    }

    self.HaveGPSData = YES;
    
    NSInteger count = self.locationArray.count;
    
    CLLocationCoordinate2D coords[count];
    
    for (int i = 0; i < self.locationArray.count; i ++) {
        
        NSString *longtitudeStr = self.locationArray[i][0];
        float longtitude = [longtitudeStr floatValue];
        
        NSString *latitudeStr = self.locationArray[i][1];
        float latitude = [latitudeStr floatValue];
        
        coords[i] = CLLocationCoordinate2DMake(longtitude,  latitude);
    }
    
    MKPolyline *crum=[MKPolyline polylineWithCoordinates:coords count:self.locationArray.count];
    [self.mapView addOverlay:crum level:MKOverlayLevelAboveRoads];
    self.mapView.visibleMapRect = crum.boundingMapRect;
    self.baseLine = crum;
    
    CGFloat durationTime = self.durationTime;
     CGFloat allGpsArrayCount = self.locationArray.count;
     CGFloat timerCount = (CGFloat)durationTime/allGpsArrayCount;
    __weak typeof(self) weakSelf = self;
    if (_heartBeatTimer == nil) {
        
        //5秒定时器发送心跳包
        _heartBeatTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(0, 0));
        dispatch_source_set_timer(_heartBeatTimer, DISPATCH_TIME_NOW, timerCount * NSEC_PER_SEC, 0 * NSEC_PER_SEC);
        dispatch_source_set_event_handler(_heartBeatTimer, ^{
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf addAnnotaion];
            });
        });
        dispatch_resume(self.heartBeatTimer);
    }
    
}


-(void)addAnnotaion
{
    if (self.annotation) {
        [self.mapView removeAnnotation:self.annotation];
    }
    if (_annotationNum > self.locationArray.count - 1 || _playFinished) {
        return;
    }
    CLLocationCoordinate2D coordinate2D;
    NSString *longtitudeStr = self.locationArray[_annotationNum][0];
    float longtitude = [longtitudeStr floatValue];
    NSString *latitudeStr = self.locationArray[_annotationNum][1];
    float latitude = [latitudeStr floatValue];
    coordinate2D = CLLocationCoordinate2DMake(longtitude,  latitude);
    
    MKPointAnnotation *pointAnntation = [[MKPointAnnotation alloc] init];
    [pointAnntation setCoordinate:coordinate2D];
    [self.mapView addAnnotation:pointAnntation];
    self.annotation = pointAnntation;
    _annotationNum++;
}


//线路的绘制
- (MKOverlayRenderer *)mapView:(MKMapView *)mapView
            rendererForOverlay:(id<MKOverlay>)overlay
{
    
    if (self.visibleLine == overlay) {
        
        MKPolylineRenderer *renderer;
        renderer = [[MKPolylineRenderer alloc] initWithOverlay:overlay];
        renderer.lineWidth = 5.0;
        renderer.strokeColor = [UIColor greenColor];
        return renderer;
    }
    
    MKPolylineRenderer *renderer;
    renderer = [[MKPolylineRenderer alloc] initWithOverlay:overlay];
    renderer.lineWidth = 5.0;
    renderer.strokeColor = [UIColor purpleColor];
    
    return renderer;
}

//设置添加大头针

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation{

    //设置大头针属性

    //优化处理 如果设置两个 内存会有问题

    static NSString *pinIndentifier = @"pin";

    MKPinAnnotationView *pinAnnotationView = (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:pinIndentifier];

    if (!pinIndentifier) {

        pinAnnotationView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:pinIndentifier];

        //    [pinAnnotationView setPinColor:MKPinAnnotationColorPurple];//已经废弃
        //大头针动画的效果 下落的样式 出现
        [pinAnnotationView setAnimatesDrop:NO];//没有出现下落的效果
        //标题显示打开
        [pinAnnotationView setCanShowCallout:NO];
        pinAnnotationView.image = [UIImage imageNamed:@"che"];

    }
    return pinAnnotationView;
}

- (void)updateProgress:(int)currentSeconds{
    
    if (!self.haveLoadVideoDuration) {
        
        self.haveLoadVideoDuration = YES;
        VLCMedia *media = self.mediaPlayer.media;
        int totalSeconds = media.length.intValue / 1000;
        self.progressSlider.maximumValue = totalSeconds;
        self.progressSlider.minimumValue = 0;
        int seconds = totalSeconds % 60;
        int minutes = totalSeconds / 60;
        NSString *durationInfo = [NSString stringWithFormat:@"%d:%02d",minutes,seconds];
        self.durationLabel.text = durationInfo;
        self.durationTime = totalSeconds;
        if (self.videoIsLocal == YES) {
            [self drawLine];
        }
    }
    
    self.progressSlider.value = currentSeconds;
    
    int seconds = currentSeconds % 60;
    int minutes = currentSeconds / 60;
    NSString *progressInfo = [NSString stringWithFormat:@"%d:%02d",minutes,seconds];
    self.progressLabel.text = progressInfo;
}


- (void)mediaPlayerTimeChanged:(NSNotification *)aNotification{
    
    if (self.flower.isAnimating) {
        
        [self.flower stopAnimating];
    }
    
    self.playFinished = NO;
    int currentSeconds = self.mediaPlayer.time.intValue / 1000;
    
//    NSLog(@"----->%d",currentSeconds);
//    VLCMedia *media = self.mediaPlayer.media;
//    NSLog(@"media length:%d",media.length.intValue);
//    NSLog(@"media player time:%d",self.mediaPlayer.time.intValue);
    
    [self updateProgress:currentSeconds];
    
}

- (void)updateProgressInfoWithState:(VLCMediaPlayerState)state{
    
    switch (state) {
        case VLCMediaPlayerStateEnded:
        case VLCMediaPlayerStateError:
        case VLCMediaPlayerStateStopped:
            self.durationLabel.text = @"00:00";
            self.progressLabel.text = @"00:00";
            self.progressSlider.value = 0;
            self.playFinished = YES;
            break;
            
        default:
            break;
    }
}

- (void)updateFlowerWithState:(VLCMediaPlayerState)state{
    
    if (state == VLCMediaPlayerStateBuffering || state == VLCMediaPlayerStateOpening) {
        
        if (!self.flower.isAnimating) {
            [self.flower startAnimating];
        }
    }
    else{
        
        if (self.flower.isAnimating) {
            [self.flower stopAnimating];
        }
    }
}

- (void)updateTipsLabelWithState:(VLCMediaPlayerState)state{
    
    if (state == VLCMediaPlayerStateError){
        
//        self.tipsLabel.text = NSLocalizedString(@"发生错误", nil);
        [APKAlertTool showAlertInViewController:self title:nil message:NSLocalizedString(@"发生错误", nil) confirmHandler:nil];
    }
    else if (state == VLCMediaPlayerStateStopped || state == VLCMediaPlayerStateEnded){
        
//        self.tipsLabel.text = self.isStopForLoadNewVideo ? nil : NSLocalizedString(@"播放结束", nil);
    }
    else{
        
//        self.tipsLabel.text = nil;
    }
}

- (void)updatePlayPauseButtonWithState:(VLCMediaPlayerState)state{
    
    switch (state) {
        case VLCMediaPlayerStateStopped:
        case VLCMediaPlayerStateEnded:
        case VLCMediaPlayerStateError:
        case VLCMediaPlayerStatePaused:
            self.playButton.hidden = NO;
            self.playButton.enabled = YES;
            self.pauseButton.hidden = YES;
            self.pauseButton.enabled = NO;
            break;
        case VLCMediaPlayerStatePlaying:
            self.playButton.hidden = YES;
            self.playButton.enabled = NO;
            self.pauseButton.hidden = NO;
            self.pauseButton.enabled = YES;
            break;
        default:
            break;
    }
}

- (void)updateSwitchVideoButtons{
    
    NSInteger numberOfVideos = self.URLs.count;
    if (numberOfVideos == 0) {
        
        self.previousButton.enabled = NO;
        self.nextButton.enabled = NO;
    }
    else{
        
        self.previousButton.enabled = self.currentIndex == 0 ? NO : YES;
        self.nextButton.enabled = self.currentIndex == (numberOfVideos - 1) ? NO : YES;
    }
}


- (IBAction)play:(UIButton *)sender {
    
    if (self.mediaPlayer.state == VLCMediaPlayerStatePaused) {
        
        int aInt = self.lastPLayTime;
        VLCTime *time = [VLCTime timeWithInt:aInt * 1000];
        [self.mediaPlayer setTime:time];
        [self.mediaPlayer play];
        
        dispatch_time_t delayTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0/*延迟执行时间*/ * NSEC_PER_SEC));

        dispatch_after(delayTime, dispatch_get_main_queue(), ^{
            if (self.videoIsLocal == YES && _HaveGPSData == YES) {
                dispatch_resume(self.heartBeatTimer);
            }
        });
    }
    else{
        
        [self loadNewVideo];
        self.annotationNum = 0;
        if (self.videoIsLocal == YES) {
            [self drawLine];
        }
    }
    self.playFinished = NO;
    
}

- (IBAction)pause:(UIButton *)sender {
    
    int currentSeconds = self.mediaPlayer.time.intValue / 1000;
    self.lastPLayTime = currentSeconds;
    [self.mediaPlayer pause];
    if (_HaveGPSData == YES) {
        dispatch_suspend(self.heartBeatTimer);
    }

}

- (IBAction)chengePlayItemWithSender:(UIButton *)sender {
    
//    [self stopMoveTrack];
    if (sender == self.previousButton) {
        
        self.currentIndex -= 1;
    }
    else if(sender == self.nextButton){
        
        self.currentIndex += 1;
    }
    [self updateSwitchVideoButtons];
    
    [self getFileName];
    
    self.localFileURL = nil;
    [self loadNewVideo];
    
    self.playFinished = NO;
    
    if (self.videoIsLocal == YES) {
        self.annotationNum = 0;
        [self drawLine];
    }
}


- (IBAction)progressSliderValueChanged:(UISlider *)sender {
    
    [self updateProgress:sender.value];
}

- (IBAction)progressSliderTouchFinished:(UISlider *)sender {
    
    int aInt = sender.value;
     VLCTime *time = [VLCTime timeWithInt:aInt * 1000];
     [self.mediaPlayer setTime:time];
     [self.mediaPlayer play];
    
//    if (_HaveGPSData == YES) {
//        dispatch_suspend(self.heartBeatTimer);
//    }
    self.annotationNum = (sender.value/_durationTime)*self.locationArray.count;
//    if (_playFinished != YES && self.videoIsLocal == YES && _HaveGPSData == YES) {
//        dispatch_resume(self.heartBeatTimer);
//    }
}



- (VLCMediaPlayer *)mediaPlayer{
    
    if (!_mediaPlayer) {
        _mediaPlayer = [[VLCMediaPlayer alloc] initWithOptions:nil];
        _mediaPlayer.drawable = _playerView;


    }
    return _mediaPlayer;
}



/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
