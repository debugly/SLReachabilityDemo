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

typedef NS_ENUM(NSUInteger, SLNetWorkStatus) {
    ///网络不可用；
    SLNetWorkStatusUnavailable,
    ///不允许WWAN网络；默认允许
    SLNetWorkStatusWWANRefused,
    ///使用wifi；
    SLNetWorkStatusWiFi,//SLNetWorkStatus not contain!
    ///使用WWAN；
    SLNetWorkStatusWWAN4G,
    SLNetWorkStatusWWAN3G,
    SLNetWorkStatusWWAN2G,
};

typedef NS_OPTIONS(NSUInteger, SLNetWorkStatusMask) {
    SLNetWorkStatusMaskUnavailable   = 1 << SLNetWorkStatusUnavailable,
    SLNetWorkStatusMaskReachableWiFi = 1 << SLNetWorkStatusWiFi,
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

NS_INLINE BOOL isWiFiWithStatus(SLReachStatus mask)
{
    return mask == SLReachableViaWiFi;
}


FOUNDATION_EXTERN NSString *const kSLReachabilityReachStatusChanged;
FOUNDATION_EXTERN NSString *const kSLReachabilityWWANChanged;
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
@property (nonatomic, assign, readonly) SLNetWorkStatus wwanType;

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
