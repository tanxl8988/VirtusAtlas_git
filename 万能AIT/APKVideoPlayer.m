//
//  APKLocalVideoPlayerVC.m
//  第三版云智汇
//
//  Created by Mac on 16/8/10.
//  Copyright © 2016年 APK. All rights reserved.
//

#import "APKVideoPlayer.h"
#import "APKAlertTool.h"
#import <MapKit/MapKit.h>
#import "APKLocalFile.h"
#import "APKHandleGpsInfoTool.h"

@implementation APKAVPlayerView

+ (Class)layerClass {
    return [AVPlayerLayer class];
}

- (AVPlayer *)player {
    return [(AVPlayerLayer *)[self layer] player];
}

- (void)setPlayer:(AVPlayer *)player {
    [(AVPlayerLayer *)[self layer] setPlayer:player];
}

@end

typedef enum : NSUInteger {
    APKVideoPlayerResourceTypeUrl,
    APKVideoPlayerResourceTypePHAsset,
} APKVideoPlayerResourceType;

static int AAPLPlayerViewControllerKVOContext = 0;

@interface APKVideoPlayer ()<MKMapViewDelegate, CLLocationManagerDelegate,UIScrollViewDelegate>

@property (weak, nonatomic) IBOutlet UIView *toolView;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *progressLabel;
@property (weak, nonatomic) IBOutlet UILabel *durationLabel;
@property (weak, nonatomic) IBOutlet UISlider *progressSlider;
@property (weak, nonatomic) IBOutlet UIButton *previousButton;
@property (weak, nonatomic) IBOutlet UIButton *nextButton;
@property (weak, nonatomic) IBOutlet UIButton *pauseButton;
@property (weak, nonatomic) IBOutlet UIButton *playButton;
@property (weak, nonatomic) IBOutlet APKAVPlayerView *playerView;
@property (nonatomic,retain) CLLocationManager *locationManager;
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *flower;
@property (assign) APKVideoPlayerResourceType resourceType;
@property (nonatomic ,strong) AVPlayer *player;
@property (strong,nonatomic) NSArray *nameArray;
@property (strong,nonatomic) id<NSObject> timeObserverToken;
@property (nonatomic) NSInteger currentIndex;
@property (strong,nonatomic) NSArray<NSURL *> *urlArray;
@property (nonatomic ,strong) AVAsset *avAsset;
@property (nonatomic ,strong) PHAsset *phAsset;
@property (strong,nonatomic) NSArray <PHAsset *>*assetArray;
@property (assign) BOOL isPausing;
@property (nonatomic,retain) NSArray *locationArray;
@property (nonatomic,retain) NSArray *localFileArr;
@property (nonatomic,retain) MKPolyline *baseLine;
@property (nonatomic,retain) NSTimer *time;
@property (nonatomic,retain) MKPolyline *lastVisibleLine;
@property (nonatomic,retain) MKPolyline *visibleLine;
@property (nonatomic,assign) BOOL isFirstShowVisibleLine;
@property (nonatomic,assign) BOOL isRemoteVideo;

@end

@implementation APKVideoPlayer

#pragma mark - life circle

- (void)viewDidLoad {
    
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    //初始化地图
    [self initWithMapView];
    //初始化定位服务管理对象
    [self initWithLocationManager];
    [_locationManager startUpdatingLocation];
    
    [self.progressSlider setThumbImage:[UIImage imageNamed:@"videoPlayer_sliderBar"] forState:UIControlStateNormal];
    [self.progressSlider setThumbImage:[UIImage imageNamed:@"videoPlayer_sliderBar"] forState:UIControlStateSelected];

    [self addObserver:self forKeyPath:@"player.currentItem.duration" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial context:&AAPLPlayerViewControllerKVOContext];
    [self addObserver:self forKeyPath:@"player.currentItem.loadedTimeRanges" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial context:&AAPLPlayerViewControllerKVOContext];
    [self addObserver:self forKeyPath:@"player.rate" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial context:&AAPLPlayerViewControllerKVOContext];
    [self addObserver:self forKeyPath:@"player.currentItem.status" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial context:&AAPLPlayerViewControllerKVOContext];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handlePlayToEndTimeNotification:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    
    self.playerView.player = self.player;
    APKVideoPlayer __weak *weakSelf = self;
    self.timeObserverToken = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 1) queue:dispatch_get_main_queue() usingBlock:
                          ^(CMTime time) {
                              
                              double seconds = CMTimeGetSeconds(time);
//                              NSLog(@"%f",seconds);
                              weakSelf.progressSlider.value = seconds;
                              weakSelf.progressLabel.text = [weakSelf formatTimeWithSeconds:seconds];
    }];

    
    [self updateUIWithCurrentIndex];
    
    [self loadAsset];
    
    self.isFirstShowVisibleLine = YES;
    [self drawLine];

    if (_isRemoteVideo == YES)
        [self.mapView removeFromSuperview];
    
    
//    self.playerView.frame = self.view.bounds;
}

//- (void)dealloc {
//
//    NSLog(@"%s",__func__);
//
//    if (self.timeObserverToken) {
//
//        [self.player removeTimeObserver:self.timeObserverToken];
//        self.timeObserverToken = nil;
//    }
//    [self.player pause];
//
//    [self removeObserver:self forKeyPath:@"player.currentItem.duration" context:&AAPLPlayerViewControllerKVOContext];
//    [self removeObserver:self forKeyPath:@"player.currentItem.loadedTimeRanges" context:&AAPLPlayerViewControllerKVOContext];
//    [self removeObserver:self forKeyPath:@"player.rate" context:&AAPLPlayerViewControllerKVOContext];
//    [self removeObserver:self forKeyPath:@"player.currentItem.status" context:&AAPLPlayerViewControllerKVOContext];
//
//    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
//}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    if (self.timeObserverToken) {
        
        [self.player removeTimeObserver:self.timeObserverToken];
        self.timeObserverToken = nil;
    }
    [self.player pause];
    
    [self removeObserver:self forKeyPath:@"player.currentItem.duration" context:&AAPLPlayerViewControllerKVOContext];
    [self removeObserver:self forKeyPath:@"player.currentItem.loadedTimeRanges" context:&AAPLPlayerViewControllerKVOContext];
    [self removeObserver:self forKeyPath:@"player.rate" context:&AAPLPlayerViewControllerKVOContext];
    [self removeObserver:self forKeyPath:@"player.currentItem.status" context:&AAPLPlayerViewControllerKVOContext];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    
    [self.time invalidate];
    self.time = nil;
}

- (void)initWithMapView
{
    _mapView.delegate = self;
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

-(void)drawLine
{
    
    APKLocalFile *file = self.localFileArr[self.currentIndex];
    
    self.locationArray = [APKHandleGpsInfoTool transformGpsInfoFromStringToArr:file.info.gpsStr];
    
//     NSArray *locationArray = @[@[@"37.93563",@"116.377358"],@[@"37.935564",@"116.376414"],@[@"37.935646",@"116.376037"],@[@"37.93586",@"116.375791"],@[@"37.93586",@"116.375791"],@[@"37.937983",@"116.37474"],@[@"37.937616",@"116.3746"],@[@"37.937888",@"116.376971"],@[@"37.937855",@"116.377047"],@[@"37.937172",@"116.377132"],@[@"37.937604",@"116.377218"],@[@"37.937489",@"116.377132"],@[@"37.93614",@"116.377283"],@[@"37.935622",@"116.377347"]];
//
//    self.locationArray = locationArray;
    
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
    
}

-(void)showVisibleLine:(int)duration
{
    CGFloat durationTime = duration;
    
    CGFloat allGpsArrayCount = self.locationArray.count;
    
    CGFloat timerCount = (CGFloat)durationTime/allGpsArrayCount;
    
    
    NSTimer *time = [NSTimer scheduledTimerWithTimeInterval:timerCount target:self selector:@selector(drawVisibleLine) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:time forMode:NSRunLoopCommonModes];
    
    self.time = time;
    
    
    //    [self setRegion];
}

 static int countNum = 0;
-(void)drawVisibleLine
{
    //    [self setRegion];
    
    [self.mapView removeOverlay:self.lastVisibleLine];//移除上一个画线
    
    NSInteger count = _locationArray.count;
    
    CLLocationCoordinate2D coords[count];
    
    for (int i = 0; i < _locationArray.count; i ++) {
        
        NSString *longtitudeStr = _locationArray[i][0];
        float longtitude = [longtitudeStr floatValue];
        
        NSString *latitudeStr = _locationArray[i][1];
        float latitude = [latitudeStr floatValue];
        
        coords[i] = CLLocationCoordinate2DMake(longtitude,  latitude);
    }
    
    self.visibleLine = [MKPolyline polylineWithCoordinates:coords count:countNum];
    [self.mapView addOverlay:self.visibleLine level:MKOverlayLevelAboveRoads];
    
    //    self.mapView.visibleMapRect = self.visibleLine.boundingMapRect;
    
    
    if (countNum == self.locationArray.count) {
        
        //        [self invalidateTime];
        [_time setFireDate:[NSDate distantFuture]];//暂停定时器
    }
    
    self.lastVisibleLine = self.visibleLine;
    countNum++;
}



-(void)invalidateTime
{
    [self.time invalidate];
    self.time = nil;
}

-(void)setRegion
{
    
    
    NSString *longtiude = self.locationArray[0][0];
    NSString *latitude = self.locationArray[0][1];
    CLLocationCoordinate2D coord = CLLocationCoordinate2DMake([longtiude floatValue],[latitude floatValue]);
    
    
    MKCoordinateSpan span = MKCoordinateSpanMake(0.005, 0.005);
    [self.mapView setRegion:MKCoordinateRegionMake(coord, span) animated:YES];
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


#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    if (context != &AAPLPlayerViewControllerKVOContext) {
        // KVO isn't for us.
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    
    if ([keyPath isEqualToString:@"player.currentItem.duration"]) {
        
//        NSLog(@"player.currentItem.duration");
        
        NSValue *newDurationAsValue = change[NSKeyValueChangeNewKey];
        CMTime newDuration = [newDurationAsValue isKindOfClass:[NSValue class]] ? newDurationAsValue.CMTimeValue : kCMTimeZero;
        BOOL hasValidDuration = CMTIME_IS_NUMERIC(newDuration) && newDuration.value != 0;
        double newDurationSeconds = hasValidDuration ? CMTimeGetSeconds(newDuration) : 0.0;
        
        self.progressSlider.maximumValue = newDurationSeconds;
        self.progressSlider.value = hasValidDuration ? CMTimeGetSeconds(self.player.currentTime) : 0.0;
        self.playButton.enabled = hasValidDuration;
        self.pauseButton.enabled = hasValidDuration;
        self.durationLabel.text = [self formatTimeWithSeconds:newDurationSeconds];
        
        if (![self.durationLabel.text isEqualToString:@"0:00"] && self.isFirstShowVisibleLine) {
            
            self.isFirstShowVisibleLine = NO;
            [self showVisibleLine:newDurationSeconds];
        }
    }
    else if ([keyPath isEqualToString:@"player.rate"]) {
        
        double newRate = [change[NSKeyValueChangeNewKey] doubleValue];
//        NSLog(@"play rate : %f",newRate);
        [self updateUIWithPlayerRate:newRate];
        
    }
    else if ([keyPath isEqualToString:@"player.currentItem.status"]) {
        
        NSNumber *newStatusAsNumber = change[NSKeyValueChangeNewKey];
        AVPlayerItemStatus newStatus = [newStatusAsNumber isKindOfClass:[NSNumber class]] ? newStatusAsNumber.integerValue : AVPlayerItemStatusUnknown;
        
        if (newStatus == AVPlayerItemStatusFailed) {
//           NSLog(@"AVPlayerItemStatusFailed");
        }else if (newStatus == AVPlayerItemStatusReadyToPlay){
//            NSLog(@"AVPlayerItemStatusReadyToPlay");
            [self play:self.playButton];
        }else{
//            NSLog(@"AVPlayerItemStatusUnknown");
        }
    }
    else if ([keyPath isEqualToString:@"player.currentItem.loadedTimeRanges"]) {
        
        NSTimeInterval timeInterval = [self availableDuration];// 计算缓冲进度
        NSLog(@"已缓存时长 : %f",timeInterval);

        if (self.player.rate == 0.f && !self.isPausing) {
            if (CMTimeGetSeconds(self.player.currentTime) < timeInterval) {
                
                [self.player play];
            }
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - getter

- (AVPlayer *)player{
    
    if (!_player) {
        _player = [[AVPlayer alloc] init];
    }
    return _player;
}

#pragma mark - private method

- (NSString *)formatTimeWithSeconds:(double)seconds{
    
    int wholeMinutes = (int)trunc(seconds / 60);
    int wholdSeconds = (int)trunc(seconds) - wholeMinutes * 60;
    NSString *formatTime = [NSString stringWithFormat:@"%d:%02d", wholeMinutes, wholdSeconds];
    return formatTime;
}

//返回 当前 视频 缓存时长
- (NSTimeInterval)availableDuration{
    NSArray *loadedTimeRanges = [[self.player currentItem] loadedTimeRanges];
    CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue];// 获取缓冲区域
    float startSeconds = CMTimeGetSeconds(timeRange.start);
    float durationSeconds = CMTimeGetSeconds(timeRange.duration);
    NSTimeInterval result = startSeconds + durationSeconds;// 计算缓冲总进度
    return result;
}

- (void)handlePlayToEndTimeNotification:(NSNotification *)notification{
    
//    NSLog(@"%@",notification.name);
    __weak typeof(self)weakSelf = self;
    [self.player seekToTime:kCMTimeZero completionHandler:^(BOOL finished) {
        
        if (finished) {
            [weakSelf.flower stopAnimating];
            [weakSelf pause:weakSelf.pauseButton];
            [weakSelf.time setFireDate:[NSDate distantFuture]];//暂停定时器
        }
    }];
}

- (void)loadPHAsset:(PHAsset *)asset{
    
    __weak typeof(self)weakSelf = self;
    [[PHImageManager defaultManager] requestPlayerItemForVideo:asset options:nil resultHandler:^(AVPlayerItem * _Nullable playerItem, NSDictionary * _Nullable info) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if (asset != weakSelf.phAsset) {
                return;
            }
           [weakSelf.player replaceCurrentItemWithPlayerItem:playerItem];
        });
    }];
}

- (void)loadAVAsset:(AVAsset *)asset{
    
    __weak typeof(self)weakSelf = self;

    NSArray *loadKeys = @[@"playable",@"hasProtectedContent"];
    [asset loadValuesAsynchronouslyForKeys:loadKeys completionHandler:^{
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if (asset != weakSelf.avAsset) {
                return;
            }
            
            //判断是否加载keys成功
            for (NSString *key in loadKeys) {
                NSError *error = nil;
                if ([asset statusOfValueForKey:key error:&error] == AVKeyValueStatusFailed) {
                    
                    NSString *message = NSLocalizedString(@"加载视频失败！", nil);
                    [APKAlertTool showAlertInViewController:weakSelf title:nil message:message confirmHandler:^(UIAlertAction *action) {
                    }];
                    return;
                }
            }
            
            //判断是否可以播放该asset
            if (!asset.playable || asset.hasProtectedContent) {
                
                NSString *message = NSLocalizedString(@"该视频不可播放！", nil);
                [APKAlertTool showAlertInViewController:weakSelf title:nil message:message confirmHandler:^(UIAlertAction *action) {
                }];
                return;
            }
            
            //可以播放该asset
            AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:asset];
            [weakSelf.player replaceCurrentItemWithPlayerItem:item];
        });
    }];
}

- (void)loadAsset{
    
    [self.player replaceCurrentItemWithPlayerItem:nil];
    self.isPausing = NO;
    [self.player pause];
    
    if (self.resourceType == APKVideoPlayerResourceTypeUrl) {
        
        NSURL *url = self.urlArray[self.currentIndex];
        AVURLAsset *asset = [AVURLAsset assetWithURL:url];
        self.avAsset = asset;
        [self loadAVAsset:asset];
        
    }else if(self.resourceType == APKVideoPlayerResourceTypePHAsset){
        
        PHAsset *asset = self.assetArray[self.currentIndex];
        self.phAsset = asset;
        [self loadPHAsset:asset];
        
        //重新画线
        countNum = 0;
        [self.mapView removeOverlay:self.baseLine];
        [self.mapView removeOverlay:self.visibleLine];
        [self drawLine];
    }
}

- (void)updateUIWithPlayerRate:(double)rate{
    
    if (rate == 1.0) {
        self.pauseButton.hidden = NO;
        self.playButton.hidden = YES;
        self.pauseButton.enabled = YES;
        [self.flower stopAnimating];
    }else{
        self.pauseButton.hidden = YES;
        self.playButton.hidden = NO;
        self.playButton.enabled = YES;
        if (!self.isPausing) {
            [self.flower startAnimating];
        }
    }
}

- (void)updateUIWithCurrentIndex{
    
    NSString *videoName = [self.nameArray objectAtIndex:self.currentIndex];
    self.titleLabel.text = videoName;
    
    NSInteger numberOfVideos = 0;
    if (self.resourceType == APKVideoPlayerResourceTypeUrl) {
        numberOfVideos = self.urlArray.count;
    }else if (self.resourceType == APKVideoPlayerResourceTypePHAsset){
        numberOfVideos = self.assetArray.count;
    }
    self.previousButton.enabled = self.currentIndex == 0 ? NO : YES;
    self.nextButton.enabled = self.currentIndex == (numberOfVideos - 1) ? NO : YES;
}

#pragma mark - public method

- (void)configurePlayerWithURLArray:(NSArray<NSURL *> *)urlArray nameArray:(NSArray *)nameArray playItemIndex:(NSInteger)playItemIndex{
    
    self.resourceType = APKVideoPlayerResourceTypeUrl;
    self.urlArray = [urlArray copy];
    self.nameArray = [nameArray copy];
    self.currentIndex = playItemIndex;
    self.isRemoteVideo = YES;
    self.playerView.center = self.view.center;
}

- (void)configurePlayerWithAssetArray:(NSArray<PHAsset *> *)assetArray nameArray:(NSArray *)nameArray playItemIndex:(NSInteger)playItemIndex fileArray:(NSArray *)fileArray{
    
    self.resourceType = APKVideoPlayerResourceTypePHAsset;
    self.assetArray = assetArray;
    self.nameArray = [nameArray copy];
    self.currentIndex = playItemIndex;
    self.localFileArr = [NSArray arrayWithArray:fileArray];
}

#pragma mark - action

- (IBAction)updateToolView:(UITapGestureRecognizer *)sender {
    
//    self.toolView.hidden = !self.toolView.hidden;
}

- (IBAction)progressSliderTouchFinished:(UISlider *)sender {
    
    [self play:self.playButton];
}

- (IBAction)progressSliderValueChanged:(UISlider *)sender {
    
    double currentTime = sender.value;
    CMTimeScale scale = self.player.currentTime.timescale;
    CMTime time = CMTimeMake(scale * currentTime, scale);
    
    __weak typeof(self)weakSelf = self;
    [self.player seekToTime:time completionHandler:^(BOOL finished) {
        
//        if (finished) {
//            NSLog(@"seek time finish == YES");
//        }else{
//            NSLog(@"seek time finish == NO");
//        }
        if ((NSInteger)currentTime < weakSelf.locationArray.count) {
            
            countNum = (int)currentTime + 1;
            
            if (!weakSelf.isPausing) [weakSelf.time setFireDate:[NSDate date]];//重启定时器
            
        }else
        {
            countNum = 0;
        }
    }];
    
    self.progressLabel.text = [self formatTimeWithSeconds:sender.value];
}

- (IBAction)progressSliderTouchDown:(UISlider *)sender {
    
    [self pause:self.pauseButton];
}

- (IBAction)play:(UIButton *)sender {
    
    self.isPausing = NO;
    [self.player play];
    
    if ([self.progressLabel.text isEqualToString:@"0:00"]) {
        countNum = 0;
        [self.mapView removeOverlay:self.lastVisibleLine];//移除上一个画线

    }
    
    [_time setFireDate:[NSDate date]];//重启定时器
}

- (IBAction)pause:(UIButton *)sender {
    
    self.isPausing = YES;
    [self.player pause];
    
    [_time setFireDate:[NSDate distantFuture]];//暂停定时器
}

- (IBAction)chengePlayItemWithSender:(UIButton *)sender {
    
    if (sender == self.previousButton) {
        self.currentIndex -= 1;
    }else if(sender == self.nextButton){
        self.currentIndex += 1;
    }
    [self updateUIWithCurrentIndex];

    [self loadAsset];
}

- (IBAction)quit {
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

































