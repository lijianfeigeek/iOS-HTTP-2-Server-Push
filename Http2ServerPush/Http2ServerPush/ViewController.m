//
//  ViewController.m
//  Http2ServerPush
//
//  Created by f.li on 2017/4/10.
//  Copyright © 2017年 Qunar. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()<NSURLSessionDelegate>

@property(nonatomic,strong)NSURLSession *session;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
}
#pragma mark - Touch
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self urlSession];
}
#pragma mark - 发送请求
- (void)urlSession
{
    NSURL *url = [NSURL URLWithString:@"https://localhost:3000"];
    
    //发送HTTPS请求是需要对网络会话设置代理的
    _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    
    NSURLSessionDataTask *dataTask = [_session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSLog(@"%@",[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
        // 收到该次请求后，立即请求下次的内容
        [self urlSessionPush];
        
    }];
    
    [dataTask resume];
}

- (void)urlSessionPush
{
    NSURL *url = [NSURL URLWithString:@"https://localhost:3000/Users/f.li/Desktop/http2-nodeServer/newpush.json"];
    NSURLSessionDataTask *dataTask = [_session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSLog(@"%@",[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    }];
    [dataTask resume];
}

#pragma mark - URLSession Delegate
- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler
{
    // 这里还要设置下 plist 中设置 ATS
    if (![challenge.protectionSpace.authenticationMethod isEqualToString:@"NSURLAuthenticationMethodServerTrust"])
    {
        return;
    }
    NSURLCredential *credential = [[NSURLCredential alloc] initWithTrust:challenge.protectionSpace.serverTrust];
    completionHandler(NSURLSessionAuthChallengeUseCredential,credential);
}


- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics
{
    NSArray *fetchTypes = @[ @"Unknown", @"Network Load", @"Server Push", @"Local Cache"];
    
    for(NSURLSessionTaskTransactionMetrics *transactionMetrics in [metrics transactionMetrics])
    {
        
        NSLog(@"protocol[%@] reuse[%d] fetch:%@ - %@", [transactionMetrics networkProtocolName], [transactionMetrics isReusedConnection], fetchTypes[[transactionMetrics resourceFetchType]], [[transactionMetrics request] URL]);
        
        if([transactionMetrics resourceFetchType] == NSURLSessionTaskMetricsResourceFetchTypeServerPush)
        {
            NSLog(@"Asset was server pushed");
        }
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
