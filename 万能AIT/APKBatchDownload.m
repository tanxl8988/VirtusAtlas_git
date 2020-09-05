//
//  APKBatchDownload.m
//  万能AIT
//
//  Created by Mac on 17/7/28.
//  Copyright © 2017年 APK. All rights reserved.
//

#import "APKBatchDownload.h"
#import "APKMOCManager.h"
#import "APKPhotosTool.h"
#import "LocalFileInfo.h"
#import "APKPhotosTool.h"
#import "AFNetworking.h"
#import "APKHandleGpsInfoTool.h"


@interface APKBatchDownload ()

@property (strong,nonatomic) NSMutableArray *downloadFiles;
@property (copy,nonatomic) APKBatchDownloadCompletionHandler completionHandler;
@property (copy,nonatomic) APKDVRFileDownloadProgressHandler progress;
@property (copy,nonatomic) APKBatchDownloadGlobalProgressHandler globalPregress;
@property (strong,nonatomic) APKDVRFileDownloadTask *downloadTask;
@property (nonatomic) BOOL isCanceled;
@property (nonatomic) NSInteger numberOfTasks;
@property (nonatomic,retain) APKHandleGpsInfoTool *handleGpsInfoTool;
@property (nonatomic,retain) NSString *savePath;
@property (nonatomic,retain) NSArray *gpsArr;
@end

@implementation APKBatchDownload

#pragma mark - private method

- (void)setupNewDownloadTask{
    
    if (self.downloadFiles.count == 0 || self.isCanceled) {
        
        self.completionHandler();
        return;
    }
    
    APKDVRFile *file = self.downloadFiles.firstObject;
    NSInteger index = self.numberOfTasks - self.downloadFiles.count + 1;
    NSString *globalPregress = [NSString stringWithFormat:@"%@(%d/%d)",file.name,(int)index,(int)self.numberOfTasks];
    self.globalPregress(globalPregress);
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *savePath = [NSTemporaryDirectory() stringByAppendingPathComponent:file.name];//保存文件的路径
    self.savePath = savePath;
    __weak typeof(self) weakSelf = self;
    self.downloadTask = [APKDVRFileDownloadTask taskWithPriority:kDownloadPriorityNormal sourcePath:file.fileDownloadPath targetPath:savePath progress:^(float progress, NSString *info) {
        
        weakSelf.progress(progress,info);
        
    } success:^{
        APKDVRFile *file = self.downloadFiles.firstObject;
        NSString *urlStr = [file.fileDownloadPath stringByReplacingOccurrencesOfString:@"MOV" withString:@"NMEA"];
        [weakSelf beginDownloadGpsData:urlStr];
        
    } failure:^{
        
        [fm removeItemAtPath:savePath error:nil];
        [weakSelf.downloadFiles removeObject:file];
        [weakSelf setupNewDownloadTask];
    }];
}

-(void)beginDownloadGpsData:(NSString*)filePath
{
    
    __weak typeof (self) weakSelf = self;
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
    
//    NSString *pathStr = [NSString stringWithFormat:@"http://ota.apical-hk.com/getfile/?path=%@",filePath];
//    NSString *str1 = [pathStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURL *URL = [NSURL URLWithString:filePath];
    NSURLRequest *request2 = [NSURLRequest requestWithURL:URL];
    
    NSURLSessionDownloadTask *downloadTask = [manager downloadTaskWithRequest:request2 progress:nil destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
        NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
        return [documentsDirectoryURL URLByAppendingPathComponent:[response suggestedFilename]];
    } completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
       
        NSString *gpsInfo = @"";
        if (!error) {
            gpsInfo = [NSString stringWithContentsOfURL:filePath encoding:NSUTF8StringEncoding error:nil];
        }
        [weakSelf.handleGpsInfoTool handleGpsInfoData:gpsInfo andCompleteBlock:^(NSArray * _Nonnull gpsDataArray) {
            weakSelf.gpsArr = [NSArray arrayWithArray:gpsDataArray];
            [weakSelf beginSaveFile];
        }];
    }];
    //重新开始下载
    [downloadTask resume];
}

-(void)beginSaveFile
{
    __weak typeof (self) weakSelf = self;
    APKDVRFile *file = self.downloadFiles.firstObject;
    NSFileManager *fm = [NSFileManager defaultManager];
    PHAssetMediaType type = file.type == APKFileTypeCapture ? PHAssetMediaTypeImage : PHAssetMediaTypeVideo;
    NSURL *url = [NSURL URLWithString:self.savePath];
    [APKPhotosTool addFileWithUrl:url fileType:type successBlock:^(NSString *identifier) {//保存到系统dvr相册
        
        NSManagedObjectContext *context = [APKMOCManager sharedInstance].context;
        [context performBlock:^{
            
            //保存到coredata
            [LocalFileInfo createWithName:file.name type:file.type isFroontCamera:file.isFrontCamera  localIdentifier:identifier date:file.fullStyleDate gpsData:weakSelf.gpsArr context:context];
            [context save:nil];
            file.isDownloaded = YES;
            
            [fm removeItemAtPath:self.savePath error:nil];
            [weakSelf.downloadFiles removeObject:file];
            [weakSelf setupNewDownloadTask];
        }];
        
    } failureBlock:^(NSError *error) {
        
        [fm removeItemAtPath:weakSelf.savePath error:nil];
        [weakSelf.downloadFiles removeObject:file];
        [weakSelf setupNewDownloadTask];
    }];
}

#pragma mark - public method

- (void)cancel{
    
    self.isCanceled = YES;
    [self.downloadTask cancel];
}

- (void)executeWithFileArray:(NSArray<APKDVRFile *> *)fileArray globalProgress:(APKBatchDownloadGlobalProgressHandler)globalProgress currentTaskProgress:(APKDVRFileDownloadProgressHandler)progress completionHandler:(APKBatchDownloadCompletionHandler)completionHandler{
    
    [self.downloadFiles setArray:fileArray];
    self.completionHandler = completionHandler;
    self.progress = progress;
    self.globalPregress = globalProgress;
    self.isCanceled = NO;
    self.numberOfTasks = fileArray.count;
    [self setupNewDownloadTask];
}

#pragma mark - getter

- (NSMutableArray *)downloadFiles{
    
    if (!_downloadFiles) {
        
        _downloadFiles = [[NSMutableArray alloc] init];
    }
    
    return _downloadFiles;
}

-(APKHandleGpsInfoTool *)handleGpsInfoTool
{
    if (!_handleGpsInfoTool) {
        _handleGpsInfoTool = [APKHandleGpsInfoTool new];
    }
    return _handleGpsInfoTool;
}

@end
