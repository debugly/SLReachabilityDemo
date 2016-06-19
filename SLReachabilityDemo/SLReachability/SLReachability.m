//
//  SLReachability.m
//  Reachability
//
//  Created by xuqianlong on 16/6/15.
//  Copyright © 2016年 Apple Inc. All rights reserved.
//

#import <arpa/inet.h>
#import <ifaddrs.h>
#import <netdb.h>
#import <sys/socket.h>
#import <netinet/in.h>

#import "SLReachability.h"

NS_INLINE SLNetWorkStatus WWANTypeWithRadioAccessTechnology(NSString* radioAcc)
{
    if (!radioAcc) {
        return SLNetWorkStatusUnavailable;
    }
    NSDictionary* WWANTypes = @{CTRadioAccessTechnologyGPRS:        @(SLNetWorkStatusWWAN2G),
                                CTRadioAccessTechnologyEdge:        @(SLNetWorkStatusWWAN2G),
                                CTRadioAccessTechnologyCDMA1x:      @(SLNetWorkStatusWWAN2G),
                                CTRadioAccessTechnologyCDMAEVDORev0:@(SLNetWorkStatusWWAN2G),
                                CTRadioAccessTechnologyCDMAEVDORevA:@(SLNetWorkStatusWWAN2G),
                                CTRadioAccessTechnologyCDMAEVDORevB:@(SLNetWorkStatusWWAN2G),
                                CTRadioAccessTechnologyeHRPD:       @(SLNetWorkStatusWWAN2G),
                                
                                CTRadioAccessTechnologyWCDMA:       @(SLNetWorkStatusWWAN3G),
                                CTRadioAccessTechnologyHSDPA:       @(SLNetWorkStatusWWAN3G),
                                CTRadioAccessTechnologyHSUPA:       @(SLNetWorkStatusWWAN3G),
                                
                                CTRadioAccessTechnologyLTE:         @(SLNetWorkStatusWWAN4G)};
    
    return [[WWANTypes objectForKey:radioAcc]intValue];
}

NSString *const kSLReachabilityReachStatusChanged = @"kSLReachabilityReachStatusChanged";
NSString *const kSLReachabilityWWANChanged = @"kSLReachabilityWWANChanged";
NSString *const kSLReachabilityMaskChanged = @"kSLReachabilityMaskChanged";

#pragma mark - SLReachability implementation

@interface SLReachability ()

@property (nonatomic, retain) CTTelephonyNetworkInfo* radioAccessInfo;

@property (nonatomic, assign) SLReachStatus reachStatus;
@property (nonatomic, assign) SLNetWorkStatus wwanType;
@property (nonatomic, assign, readwrite) SLNetWorkStatusMask netWorkMask;
@property (nonatomic, copy) void(^ProviderDidUpdate)(CTCarrier* carrier);

- (void)updateNetworkStatusMask;

@end

@implementation SLReachability
{
    SCNetworkReachabilityRef _reachabilityRef;
}

#pragma mark - Supporting functions

///网络状况变化回调；
static void ReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info)
{
#pragma unused (target, flags)
    
    if(info == NULL) return;
    if(![(__bridge NSObject*) info isKindOfClass: [SLReachability class]]) return;
    
    SLReachability* noteObject = (__bridge SLReachability *)info;
    ///update
    noteObject.reachStatus = [noteObject currentReachabilityStatus];
}

- (void)cellularProviderDidUpdate:(void(^)(CTCarrier * carrier))ablock
{
    self.ProviderDidUpdate = ablock;
}

- (void)postNotifi:(NSString *)name
{
    [[NSNotificationCenter defaultCenter]postNotificationName:name object:self];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        NSAssert(NO, @"use reachabilityWith***");
    }
    return self;
}

- (instancetype)_init
{
    self = [super init];
    if (self) {
        // 细分WWAN；
        __weak __typeof(self)wself = self;
        _radioAccessInfo =[[CTTelephonyNetworkInfo alloc]init];
        _radioAccessInfo.subscriberCellularProviderDidUpdateNotifier = ^ (CTCarrier * carrier)
        {
            __strong __typeof(wself)self = wself;
            if(self.ProviderDidUpdate){
                self.ProviderDidUpdate(carrier);
            }
        };
        _netWorkMask = SLNetWorkStatusMaskUnavailable;
        _wwanType = SLNetWorkStatusUnavailable;
        _reachStatus = SLNotReachable;
        _allowUseWWAN = YES;
    }
    return self;
}

+ (void)_initAndStartNotifier:(SLReachability*)returnValue
{
    if (returnValue) {
        returnValue->_reachStatus = [returnValue currentReachabilityStatus];
        returnValue->_wwanType = [returnValue currentRadioAccessTechnology];
        [returnValue updateNetworkStatusMask];
        dispatch_async(dispatch_get_main_queue(), ^{
            //start observe
            [returnValue startNotifier];
        });
    }
}

+ (instancetype)reachabilityWithHostName:(NSString *)hostName
{
    SLReachability* returnValue = NULL;
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(NULL, [hostName UTF8String]);
    if (reachability != NULL)
    {
        returnValue= [[self alloc] _init];
        if (returnValue != NULL)
        {
            returnValue->_reachabilityRef = reachability;
        }
        else {
            CFRelease(reachability);
        }
    }
    
    [self _initAndStartNotifier:returnValue];
    return returnValue;
}

+ (instancetype)reachabilityWithAddress:(const struct sockaddr *)hostAddress
{
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, hostAddress);
    
    SLReachability* returnValue = NULL;
    
    if (reachability != NULL)
    {
        returnValue = [[self alloc] _init];
        if (returnValue != NULL)
        {
            returnValue->_reachabilityRef = reachability;
        }
        else {
            CFRelease(reachability);
        }
    }
    
    [self _initAndStartNotifier:returnValue];
    
    return returnValue;
}

+ (instancetype)reachabilityForInternetConnection
{
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;
    
    return [self reachabilityWithAddress: (const struct sockaddr *) &zeroAddress];
}

#pragma mark - Start and stop notifier

- (BOOL)startNotifier
{
    if (!_reachabilityRef) {
        return NO;
    }
    
    BOOL returnValue = NO;
    SCNetworkReachabilityContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
    
    if (SCNetworkReachabilitySetCallback(_reachabilityRef, ReachabilityCallback, &context))
    {
        if (SCNetworkReachabilityScheduleWithRunLoop(_reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode))
        {
            returnValue = YES;
        }
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(WWANDidChanged:)
                                                 name:CTRadioAccessTechnologyDidChangeNotification object:nil];
    
    return returnValue;
}

- (void)WWANDidChanged:(NSNotification *)notifi
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *radioAcc = [notifi object];
        SLNetWorkStatus wwanType = WWANTypeWithRadioAccessTechnology(radioAcc);
        self.wwanType = wwanType;
    });
}

- (void)stopNotifier
{
    if (_reachabilityRef != NULL)
    {
        SCNetworkReachabilityUnscheduleFromRunLoop(_reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self name:CTRadioAccessTechnologyDidChangeNotification object:nil];
}

- (void)dealloc
{
    [self stopNotifier];
    if (_reachabilityRef != NULL)
    {
        CFRelease(_reachabilityRef);
    }
}


#pragma mark - Network Flag Handling

- (SLReachStatus)networkStatusForFlags:(SCNetworkReachabilityFlags)flags
{
    if ((flags & kSCNetworkReachabilityFlagsReachable) == 0)
    {
        // The target host is not reachable.
        return SLNotReachable;
    }
    
    SLReachStatus returnValue = SLNotReachable;
    
    if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0)
    {
        /*
         If the target host is reachable and no connection is required then we'll assume (for now) that you're on Wi-Fi...
         */
        returnValue = SLReachableViaWiFi;
    }
    
    if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) ||
         (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0))
    {
        /*
         ... and the connection is on-demand (or on-traffic) if the calling application is using the CFSocketStream or higher APIs...
         */
        
        if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0)
        {
            /*
             ... and no [user] intervention is needed...
             */
            returnValue = SLReachableViaWiFi;
        }
    }
    
    if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN)
    {
        /*
         ... but WWAN connections are OK if the calling application is using the CFNetwork APIs.
         */
        returnValue = SLReachableViaWWAN;
    }
    
    return returnValue;
}

- (SLReachStatus)currentReachabilityStatus
{
    NSAssert(_reachabilityRef != NULL, @"currentNetworkStatus called with NULL SCNetworkReachabilityRef");
    SLReachStatus returnValue = SLNotReachable;
    SCNetworkReachabilityFlags flags;
    
    if (SCNetworkReachabilityGetFlags(_reachabilityRef, &flags))
    {
        returnValue = [self networkStatusForFlags:flags];
    }
    
    return returnValue;
}

#pragma mark - wwan 网络

- (SLNetWorkStatus)currentRadioAccessTechnology
{
    NSString *radioAcc = [self.radioAccessInfo currentRadioAccessTechnology];
    SLNetWorkStatus type = WWANTypeWithRadioAccessTechnology(radioAcc);
    return type;
}

#pragma mark - 更新网络状态

- (SLNetWorkStatusMask)netWorkStatusMaskWithNetStatus:(SLReachStatus) netStatus WWANType:(SLNetWorkStatus)wwanType WWANReachable:(BOOL)wwanReachable
{
    SLNetWorkStatusMask mask = 0;
    switch (netStatus) {
        case SLNotReachable:
        {
            mask = SLNetWorkStatusMaskUnavailable;
        }
            break;
        case SLReachableViaWiFi:
        {
            mask = SLNetWorkStatusMaskReachableWiFi;
        }
            break;
        case SLReachableViaWWAN:
        {
            mask = 1 << wwanType;
        }
            break;
    }
    return mask;
}

#pragma mark - update property

- (void)updateNetworkStatusMask
{
    //update
    SLNetWorkStatusMask mask = [self netWorkStatusMaskWithNetStatus:_reachStatus WWANType:_wwanType WWANReachable:_allowUseWWAN];
    self.netWorkMask = mask;
    [self postNotifi:kSLReachabilityMaskChanged];
    //log it
#ifdef DEBUG
    NSLog(@"net is: [%@]",SLNetWorkStatusMask2String(mask));
#endif
}

- (void)setWwanType:(SLNetWorkStatus)wwanType
{
    if (_wwanType != wwanType) {
        _wwanType = wwanType;
        [self updateNetworkStatusMask];
        [self postNotifi:kSLReachabilityWWANChanged];
    }
}

- (void)setAllowUseWWAN:(BOOL)allowUseWWAN
{
    if(_allowUseWWAN != allowUseWWAN)
    {
        _allowUseWWAN = allowUseWWAN;
        [self updateNetworkStatusMask];
    }
}

- (void)setReachStatus:(SLReachStatus)reachStatus
{
    if(_reachStatus != reachStatus)
    {
        _reachStatus = reachStatus;
        [self updateNetworkStatusMask];
        [self postNotifi:kSLReachabilityReachStatusChanged];
    }
}

@end
