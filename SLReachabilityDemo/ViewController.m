//
//  ViewController.m
//  SLReachabilityDemo
//
//  Created by xuqianlong on 16/6/19.
//  Copyright © 2016年 debugly. All rights reserved.
//

#import "ViewController.h"
#import "SLReachability.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UILabel *statusLb;
@property (nonatomic, strong) SLReachability *reach;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    _reach = [SLReachability reachabilityForInternetConnection];
    //添加 observer
    [_reach addObserver:self forKeyPath:@"netWorkMask" options:NSKeyValueObservingOptionNew context:nil];
    //获取当前的网络状态；
    SLNetWorkStatusMask mask = _reach.netWorkMask;
    [self updateUI:mask];
}

- (void)dealloc
{
    [_reach removeObserver:self forKeyPath:@"netWorkMask"];
    _reach = nil;
}

- (void)updateUI:(SLNetWorkStatusMask)mask
{
    self.statusLb.text = SLNetWorkStatusMask2String(mask);
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    NSNumber *statusNum = [change objectForKey:NSKeyValueChangeNewKey];
    SLNetWorkStatusMask mask = [statusNum intValue];
    [self updateUI:mask];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
