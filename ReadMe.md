
SLReachability 与 Reachability 的区别
====================================

Reachability 只能检测网络的变化，包括 WiFi ，WWAN 和 NoReachable；不能细分 WWAN，不能参与用户的设置（某些App在设置里有设置允许使用3G的开关）；

SLReachability 兼容 Reachability ，因为内部关于网络变化的实现和 Reachability 一样，完全 copy 过来的；另外还检测了 WWAN 的变化，并且考虑到了用户可能会增加允许使用 WWAN 的开关；SLReachability 把以上几种网络情况最终作了统一，方便开发者使用；

这是 Reachability 源码的地址：[https://developer.apple.com/library/prerelease/content/samplecode/Reachability/Listings/Reachability_Reachability_h.html][1]

设计思路
=======
首要要完全兼容 Reachability ，具备 Reachability 的所有功能，其次还要拥有上面提到的检测 WWAN 变化的需求和允许用户增加开关；先看下如何兼容：

- 完全兼容 Reachability 实现

```objc
typedef NS_ENUM(NSInteger,SLReachStatus) {
    SLNotReachable = 0,
    SLReachableViaWiFi,
    SLReachableViaWWAN
};

@property (nonatomic, assign, readonly) SLReachStatus reachStatus;

```
这个没什么难理解的，不在细说了；

- 检测 WWAN 的变化，这里有一下几种情况，SLNetWorkStatusWWANRefused 表示当前是 WWAN 网络，但是用户设置开关是关，不允许使用；

```objc
typedef NS_ENUM(NSUInteger, SLWWANStatus) {
    SLWWANNotReachable = SLNotReachable,
    ///不允许WWAN网络；默认允许
    SLNetWorkStatusWWANRefused = 3,
    ///使用WWAN；
    SLNetWorkStatusWWAN4G = 4,
    SLNetWorkStatusWWAN3G = 5,
    SLNetWorkStatusWWAN2G = 6,
};

@property (nonatomic, assign, readonly) SLNetWorkStatus wwanType;

```

- 统一所有的网络状况

```objc
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

```

这里需要解释下：

|--Mask--|--含义--|
|--------|---------|
|SLNetWorkStatusMaskReachableWWAN|只要当前是 2G，3G，4G 网络的一种属于ReachableWWAN|
|SLNetWorkStatusMaskNotReachable|当前没有网络 或者 当前是WWAN网络 (用户不允许)|
|SLNetWorkStatusMaskReachable|当前是WiFi网络 或者 当前是WWAN网络（用户允许）|


便利方法：
=======

判断当前网络是不是 WiFi，当然你也可以扩展更多：

```objc
NS_INLINE BOOL isWiFiWithMask(SLNetWorkStatusMask mask)
{
    return mask & SLNetWorkStatusMaskReachableWiFi;
}

NS_INLINE BOOL isWiFiWithStatus(SLReachStatus status)
{
    return mask == SLReachableViaWiFi;
}

```


使用方法1
========
```objc
 _reach = [SLReachability reachabilityForInternetConnection];
    //添加 observer
    [_reach addObserver:self forKeyPath:@"netWorkMask" options:NSKeyValueObservingOptionNew context:nil];
    //获取当前的网络状态；
    SLNetWorkStatusMask mask = _reach.netWorkMask;
```
处理网络变化：

```objc
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    NSNumber *statusNum = [change objectForKey:NSKeyValueChangeNewKey];
    SLNetWorkStatusMask mask = [statusNum intValue];
    //根据当前网络做出处理；
}
```

使用方法2
========
除了可以 Observe 属性之外，当然也可以注册通知：

```objc
///网络状态变化，同 Reachability
FOUNDATION_EXTERN NSString *const kSLReachabilityReachStatusChanged;
///WWAN变化；WiFi网络也会变，跟当前网络有关；
FOUNDATION_EXTERN NSString *const kSLReachabilityWWANChanged;
///统一后的网络变化
FOUNDATION_EXTERN NSString *const kSLReachabilityMaskChanged;
```


IPv6 Support
============
SLReachability 完全支持 IPv6 ，具体可参照 Reachability 的解释或者查看源码。

