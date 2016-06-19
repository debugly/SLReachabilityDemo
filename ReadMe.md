
故事背景
=======
Reachability 只能检测网络的变化，包括 WiFi ，WWAN 和 NoReachable 三种状态；她不能细分 WWAN 网络，不能参与用户的设置（某些App在设置里设有允许使用3G的开关），但是实际业务中我们会遇见这些情景，为了更加方便的获取、管理网络的各种状态，**SLReachability** 就运应而生了，现在她已经在两个项目里投入使用了，感觉还是挺方便的，现在拿来分享下。

SLReachability 与 Reachability 的区别
====================================



SLReachability 完全兼容 Reachability ，因为内部关于网络变化的实现是和 Reachability 一样的，老实说就是完全 copy 过来的；在 Reachability 的基础之上，增加了检测 WWAN 变化的功能，并且考虑到了用户可能会增加允许使用 WWAN 的开关；SLReachability 就是把以上几种网络情况最终作了个大统一，更加方便开发者获取网络的状态！

这是陪伴我好久的 [Reachability](https://developer.apple.com/library/prerelease/content/samplecode/Reachability/Listings/Reachability_Reachability_h.html) 源码地址.

设计思路
=======
清楚了需求后，就是一步步实现了，首要需要的是完全兼容 Reachability ，具备 Reachability 的所有功能，其次还要拥有上面提到的检测 WWAN 变化的需求和允许用户增加开关；先看下如何兼容：

- 完全兼容（copy） Reachability 实现 

```objc
typedef NS_ENUM(NSInteger,SLReachStatus) {
    SLNotReachable = 0,
    SLReachableViaWiFi,
    SLReachableViaWWAN
};

@property (nonatomic, assign, readonly) SLReachStatus reachStatus;

```
这个没什么难理解的，不再细说了；

- 下面是检测 WWAN 变化的实现，这里有以下几种情况，其中 SLNetWorkStatusWWANRefused 表示用户设置开关是关，不允许使用 WWAN 网络，出现的条件是：**没有WiFi，用户不允许使用 WWAN**；

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

- 统一所有的网络状况，这是才是今天的主要工作：

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
根据网络的情况定义了以上枚举，这里简单解释下：

|--Mask--|--含义--|
|--------|---------|
|SLNetWorkStatusMaskReachableWWAN|只要当前是 2G，3G，4G 网络的一种属于ReachableWWAN|
|SLNetWorkStatusMaskNotReachable|当前没有网络 或者 当前是WWAN网络 (用户不允许)|
|SLNetWorkStatusMaskReachable|当前是WiFi网络 或者 当前是WWAN网络（用户允许）|

实现原理
=======

使用 Reachability 检测网络的变化， 使用 iOS7 新增的 API 检测 WWAN 的变化，也正因为如此，所以 SLReachability 从 iOS7 开始支持；每当检测到变化之后就就去更新网络状态 mask ，如果前后不一致就更新，并且发送通知，反之则忽略；这里对于不一致的判断是重写了 setter 方法来实现的，下面简单看下代码：

这是 Reachability 检测到网络变化后的回调，我的处理是给属性赋值，具体更新的方法在 setter 里去实现！

```objc
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

```

下面看下对 WWAN 的检测，需要创建这样一个对象才能去观察哦：

```objc

_radioAccessInfo =[[CTTelephonyNetworkInfo alloc]init];

[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(WWANDidChanged:)
                                                 name:CTRadioAccessTechnologyDidChangeNotification object:nil];
    
```

看下通知回调的处理：

```objc
- (void)WWANDidChanged:(NSNotification *)notifi
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *radioAcc = [notifi object];
        SLWWANStatus wwanType = WWANTypeWithRadioAccessTechnology(radioAcc);
        self.wwanType = wwanType;
    });
}

```

需要注意的是，这个回调不在主线里！处理同样很简单，给属性赋值！因此如果关系 WWAN 的变化，可以直接 Observe 这个属性，需要了解的是当前网络即使是 WiFi ，这个属性也会发生变化，这跟你的移动网络有关系，但是不会影响到 mask ，因为 mask 是 WiFi ！


下面看下重写 setter 方法吧：

```objc
- (void)setWwanType:(SLWWANStatus)wwanType
{
    if (_wwanType != wwanType) {
        _wwanType = wwanType;
        [self updateNetworkStatusMask];
        [self postNotifi:kSLReachabilityWWANChanged];
    }
}

//修改了设置里的开关
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

```
通过重写 setter 的方法去被动发现网络变化了，最终通过 updateNetworkStatusMask 方法去更新 mask :

```objc
- (void)updateNetworkStatusMask
{
    //update
    SLNetWorkStatusMask mask = [self netWorkStatusMaskWithNetStatus:_reachStatus WWANType:_wwanType WWANReachable:_allowUseWWAN];
    self.netWorkMask = mask;
    //log it
#ifdef DEBUG
    NSLog(@"net is: [%@]",SLNetWorkStatusMask2String(mask));
#endif
}
```

updateNetworkStatusMask 方法根据当前的网络和WWAN情况和用户设置的选项综合出来一个最终的 mask ，当 mask 变了之后就会发送通知告知发生了变化！

```objc
- (void)setNetWorkMask:(SLNetWorkStatusMask)netWorkMask
{
    if(_netWorkMask != netWorkMask)
    {
        _netWorkMask = netWorkMask;
        [self postNotifi:kSLReachabilityMaskChanged];
    }
}
```
以上就是实现的原理，关于 allowUseWWAN 这个属性，你可以写个 SLReachability 的子类，子类检测到开关变化后去更改这个属性；不同的业务也许会有多个开关，这是一一创建子类就行了！

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

根据你的需要去注册，你可能要注意下他们 3 个之间的关系！


IPv6 Support
============
SLReachability 完全支持 IPv6 ，具体可参照 Reachability 的解释或者查看源码。

