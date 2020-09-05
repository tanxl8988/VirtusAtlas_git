//
//  APKHandleGpsInfoTool.h
//  Innowa
//
//  Created by apical on 2018/10/30.
//  Copyright © 2018年 APK. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface APKHandleGpsInfoTool : NSObject

@property (nonatomic,copy) void(^completeBlock)(NSArray *gpsDataArray);

@property (nonatomic,retain) NSString *nihao;

+(NSArray*)transformGpsInfoFromStringToArr:(NSString*)gpsStr;
+(NSString*)transformNmeaDataToGpsPoint:(NSString*)nmeaData;

-(void)handleGpsInfoData:(NSString *)nmeaDataStr andCompleteBlock:(void (^)(NSArray *gpsDataArray))completeBlock;


@end

NS_ASSUME_NONNULL_END
