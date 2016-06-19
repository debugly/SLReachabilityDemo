//
//  SLReachability.h
//  Reachability
//
//  Created by xuqianlong on 16/6/15.
//  Copyright © 2016年 Apple Inc. All rights reserved.

//SLReachability fully support IPv6.

//!!! copy some Reachability.

//!!! support iOS 7 or later system. 

//Reachability fully support IPv6.

//auto start observer!

@import Foundation;
@import SystemConfiguration;
@import CoreTelephony;


typedef NS_ENUM(NSInteger,SLReachStatus) {
    SLNotReachable = 0,
    SLReachableViaWiFi,
    SLReachableViaWWAN
};

typedef NS_ENUM(NSUInteger, SLWWANStatus) {
    SLWWANNotReachable = SLNotReachable,
    ///不允许WWAN网络；默认允许
    SLNetWorkStatusWWANRefused = 3,
    ///使用WWAN；
    SLNetWorkStatusWWAN4G = 4,
    SLNetWorkStatusWWAN3G = 5,
    SLNetWorkStatusWWAN2G = 6,
};

typedef NS_ENUM(NSUInteger, SLNetWorkStatusMask) {
    SLNetWorkStatusMaskUnavailable   = 1 << SLNotReachable,
    SLNetWorkStatusMaskReachableWiFi = 1 << SLReachableViaWiFi,//这里直接使用这个枚举即可
    SLNetWorkStatusMaskWWANRefused   = 1 << SLNetWorkStatusWWANRefused,
    
    SLNetWorkStatusMaskReachableWWAN4G = 1 << SLNetWorkStatusWWAN4G,
    SLNetWorkStatusMaskReachableWWAN3G = 1 << SLNetWorkStatusWWAN3G,
    SLNetWorkStatusMaskReachableWWAN2G = 1 << SLNetWorkStatusWWAN2G,
    
    SLNetWorkStatusMaskReachableWWAN = (SLNetWorkStatusMaskReachableWWAN2G | SLNetWorkStatusMaskReachableWWAN3G | SLNetWorkStatusMaskReachableWWAN4G),
    SLNetWorkStatusMaskNotReachable  = (SLNetWorkStatusMaskUnavailable     | SLNetWorkStatusMaskWWANRefused),
    SLNetWorkStatusMaskReachable     = (SLNetWorkStatusMaskReachableWiFi   | SLNetWorkStatusMaskReachableWWAN),
};

NS_INLINE BOOL isWiFiWithMask(SLNetWorkStatusMask mask)
{
    return mask & SLNetWorkStatusMaskReachableWiFi;
}

NS_INLINE BOOL isWiFiWithStatus(SLReachStatus status)
{
    return status == SLReachableViaWiFi;
}

///网络状态变化，同 Reachability
FOUNDATION_EXTERN NSString *const kSLReachabilityReachStatusChanged;
///WWAN变化；WiFi网络也会变，跟当前网络有关；
FOUNDATION_EXTERN NSString *const kSLReachabilityWWANChanged;
///统一后的网络变化
FOUNDATION_EXTERN NSString *const kSLReachabilityMaskChanged;

@interface SLReachability : NSObject

/*!
 * unavailable! use reachabilityWith**;
 */
- (instancetype)init NS_UNAVAILABLE;
/*!
 * Use to check the reachability of a given host name.
 */
+ (instancetype)reachabilityWithHostName:(NSString *)hostName;

/*!
 * Use to check the reachability of a given IP address.
 */
+ (instancetype)reachabilityWithAddress:(const struct sockaddr *)hostAddress;

/*!
 * Checks whether the default route is available. Should be used by applications that do not connect to a particular host.
 */
+ (instancetype)reachabilityForInternetConnection;

///you can observer them；
///网络总体情况；
@property (nonatomic, assign, readonly) SLNetWorkStatusMask netWorkMask;
///reachable: Wifi-WWAN-NotReach
@property (nonatomic, assign, readonly) SLReachStatus reachStatus;
///WWAN: 2、3、4G
@property (nonatomic, assign, readonly) SLWWANStatus wwanType;

///default is yes,sub class can assign me;
@property (nonatomic, assign, getter=isAllowUseWWAN)BOOL allowUseWWAN;

///cellular provider did update;
- (void)cellularProviderDidUpdate:(void(^)(CTCarrier * carrier))ablock;

@end

///log network mask to debug;
NS_INLINE NSString * SLNetWorkStatusMask2String(SLNetWorkStatusMask mask){
    switch (mask) {
        case SLNetWorkStatusMaskUnavailable:
            return @"没有网络！";
        case SLNetWorkStatusMaskReachableWiFi:
            return @"WiFi";
        case SLNetWorkStatusMaskWWANRefused:
            return @"不允许使用WWAN";
        case SLNetWorkStatusMaskReachableWWAN4G:
            return @"4G";
        case SLNetWorkStatusMaskReachableWWAN3G:
            return @"3G";
        case SLNetWorkStatusMaskReachableWWAN2G:
            return @"2G";
        case SLNetWorkStatusMaskReachableWWAN:
            return @"WWAN";
        case SLNetWorkStatusMaskNotReachable:
            return @"没有网络或者不允许使用WWAN";
        case SLNetWorkStatusMaskReachable:
            return @"WiFi或者WWAN";
        default:
            return nil;
    }
}
