//
//  MStarUpgradeHandler.m
//  RoavCam
//
//  Created by ocean on 2018/2/2.
//  Copyright © 2018年 Oceanwing. All rights reserved.
//

#import "MStarUpgradeHandler.h"
#import "AFNetworking.h"
static const BOOL totalUploadUpgrade = NO;//分包上传
const NSInteger fileSizePerTime = 1024 * 100; // 100k
NSString * otaSuccessString = @"ApkOtaMD5Status:ok";

@implementation MStarUpgradeHandler
{
    NSTimer * checkTimer_;
    BOOL uploadErrorOccur_;
    NSMutableArray * dataTaskCacher_;
    NSTimer * queryOTAStatusTimer_;
    dispatch_semaphore_t semaphore;
    BOOL reStartTriggerred_;
}

-(void) threadSafeUpgradeWithFilePath : (NSString *) path cb : (MStarUpgradeResult)cb progress : (MStarUpgradeProgress) progressCb completionHandle:(completionHandle)completion;{
    
    dataTaskCacher_ = [NSMutableArray array];
    _resultCB = cb;
    _progressCB = progressCb;
    _completion = completion;
    dispatch_queue_t newQueue = dispatch_queue_create("mstar upload queue", DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(newQueue, ^{
        [self startUpgradeWithFilePath:path cb:cb progress:progressCb];
    });
    reStartTriggerred_ = NO;
//    queryOTAStatusTimer_ = [NSTimer scheduledTimerWithTimeInterval:2 repeats:YES block:^(NSTimer * _Nonnull timer) {
//        [self queryOTAStatus];
//    }];
}

-(void)startUpgradeWithFilePath:(NSString *)path cb:(MStarUpgradeResult)cb progress : (MStarUpgradeProgress) progressCb
{
    
    if([NSThread currentThread] == [NSThread mainThread]) {
        NSException * exception = [NSException exceptionWithName:@"Thread Mismatch" reason:@"this method should never called in main thread" userInfo:nil];
        [exception raise];
    }
    
    uploadErrorOccur_ = NO;
    if(![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        _resultCB(NO, @"file not exist");
        return;
    }
    
    NSFileHandle * fileHandler = [NSFileHandle fileHandleForReadingAtPath:path];
    unsigned long long fileSize = fileHandler.seekToEndOfFile;
    [fileHandler seekToFileOffset:0];
    NSURLSession * urlSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    
    semaphore = dispatch_semaphore_create(1);
    
    NSURLSessionDataTask * dataTask;
    
    unsigned long long readDataLen;
    NSData * readData;
    
    if(totalUploadUpgrade) {
        readData = [fileHandler readDataOfLength:fileSize]; //整包上传走这里
    } else {
        readData = [fileHandler readDataOfLength:fileSizePerTime]; // 分包上传走这里
    }
    
    readDataLen = readData.length;
    NSInteger fileCnt = 0;
    
    while(readDataLen > 0) {
        float progress = (float)fileHandler.offsetInFile / (float)fileSize;
        if(!totalUploadUpgrade) {
            _progressCB(progress);
        }
    
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        
        if(uploadErrorOccur_ == YES) {
            NSLog(@"file upload error occur here");
            dispatch_semaphore_signal(semaphore);
            break;
        }
        
        fileCnt += 1;
        NSString * fileName;
        if(totalUploadUpgrade) {
            fileName = @"SD_CarDV.bin00end";
        } else {
            if(fileSize == [fileHandler offsetInFile]) { //last file
                fileName = [NSString stringWithFormat:@"SD_CarDV.bin%02ziend",fileCnt - 1];
            } else {
                fileName = [NSString stringWithFormat:@"SD_CarDV.bin%02zi",fileCnt - 1];
            }
        }
        
        //create request here
        NSString * boundaryString = @"ThisIsBoundaryString";
        NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://192.72.1.1/cgi-bin/FWupload.cgi"]];
        [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@",boundaryString] forHTTPHeaderField:@"Content-Type"];
        request.HTTPMethod = @"POST";
        
        NSMutableData * bodyData = [NSMutableData data];
        [bodyData appendData:[[NSString stringWithFormat:@"--%@\r\n",boundaryString] dataUsingEncoding:NSUTF8StringEncoding]];
        [bodyData appendData:[[NSString stringWithFormat:@"Content-Disposition:form-data; name=\"file\"; filename=\"%@\"\r\n",fileName] dataUsingEncoding:NSUTF8StringEncoding]];
        [bodyData appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
        [bodyData appendData:readData];
        [bodyData appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
        [bodyData appendData:[[NSString stringWithFormat:@"--%@--\r\n",boundaryString] dataUsingEncoding:NSUTF8StringEncoding]];
        [bodyData appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
        request.HTTPBody = bodyData;
        
        NSLog(@"mstar upload test : filename : %@ datalen : %zi",fileName, bodyData.length);
        if(totalUploadUpgrade) {
            AFURLSessionManager * afsManager = [[AFURLSessionManager alloc] initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
            
            
            dataTask = [afsManager dataTaskWithRequest:request uploadProgress:^(NSProgress * _Nonnull uploadProgress) {
                float total = (float)uploadProgress.totalUnitCount;
                float complete = (float)uploadProgress.completedUnitCount;
                if(progressCb) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        progressCb(complete / total);
                    });
                }
                ;
            } downloadProgress:^(NSProgress * _Nonnull downloadProgress) {
                ;
            } completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                if(error) {
                    uploadErrorOccur_ = YES;
                } else {
                    //success, continue next upload
                }
                dispatch_semaphore_signal(semaphore);
                ;
            }];
        } else {
            dataTask = [urlSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                if(error) {
                    uploadErrorOccur_ = YES;
                } else {
                    //success, continue next upload
                }
                dispatch_semaphore_signal(semaphore);
                ;
            }];
        }
        
        [dataTaskCacher_ addObject:dataTask];
        [dataTask resume];
        
        readData = [fileHandler readDataOfLength:fileSizePerTime];
        readDataLen = readData.length;
    }
    
    if(totalUploadUpgrade) {
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    }
    
//    long waitRst = dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);//wait for the last request over
    
    if(uploadErrorOccur_) {
        _resultCB(NO, nil);
    } else {
        //upload success here
//        _resultCB(YES, @"only upload success, you need check md5 result and restart manually");
        dispatch_async(dispatch_get_main_queue(), ^{
//            queryOTAStatusTimer_ = [NSTimer scheduledTimerWithTimeInterval:2 repeats:YES block:^(NSTimer * _Nonnull timer) {
//                [self queryOTAStatus];;
//            }];
           
            dispatch_time_t delayTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0/*延迟执行时间*/ * NSEC_PER_SEC));
            dispatch_after(delayTime, dispatch_get_main_queue(), ^{
                 _resultCB(YES,nil);
                self.completion();
            });
            
        });
    

        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10000 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//            if(!reStartTriggerred_) {
//                [queryOTAStatusTimer_ invalidate];
//                queryOTAStatusTimer_ = nil;
//                _resultCB(NO, nil);
//            }
            _resultCB(NO, nil);

        });
    }
    
//    semaphore = nil;
}


-(void) queryOTAStatus {
    
//    return;
    NSURLSession * session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    NSURLSessionDataTask * dataTask = [session dataTaskWithURL:[NSURL URLWithString:@"http://192.72.1.1/cgi-bin/Config.cgi?action=get&property=Camera.Menu.ApkOtaMD5Status"] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSString * str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"mstar upload test : %@",str);
        //ApkOtaMD5Status:ok
        ;
        
        if([str rangeOfString:otaSuccessString].location != NSNotFound) {
            //success here
            if(!reStartTriggerred_) {
                reStartTriggerred_ = YES;
                _resultCB(YES,@"md5 check ok");
                [self triggerRestartDevice];
            }
            [queryOTAStatusTimer_ invalidate];
            queryOTAStatusTimer_ = nil;
        }
    }];
    [dataTaskCacher_ addObject:dataTask];
    [dataTask resume];
}

-(void) triggerRestartDevice {
    
    NSURLSession * session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    NSURLSessionDataTask * dataTask = [session dataTaskWithURL:[NSURL URLWithString:@"http://192.72.1.1/cgi-bin/Config.cgi?action=set&property=PowerReset&value=Camera"] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if(!error) {
            NSLog(@"mstar upload test restart ok");
        }
    }];
    [dataTaskCacher_ addObject:dataTask];
    [dataTask resume];
}




@end
