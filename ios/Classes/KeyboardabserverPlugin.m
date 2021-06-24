#import "KeyboardabserverPlugin.h"

@interface KeyboardabserverPlugin ()<FlutterStreamHandler>

//事件的channel
@property(nonatomic,weak) FlutterEventChannel* eventChannel;

//事件的event
@property(nonatomic,strong) FlutterEventSink eventSink;

//frameView
@property(nonatomic,strong) UIView* frameView;

//高度
@property(nonatomic,assign) double height;

//宽度
@property(nonatomic,assign) double width;

@end


@implementation KeyboardabserverPlugin


+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    //创建Event
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"keyboardabserver"
                                     binaryMessenger:[registrar messenger]];
    
    //创建eventChannel
    FlutterEventChannel* eventChannel=[FlutterEventChannel eventChannelWithName:@"keyboardabserver_event"
                                                                binaryMessenger:[registrar messenger]];
    //初始化
    KeyboardabserverPlugin* instance = [[KeyboardabserverPlugin alloc] init];
    
    //赋值eventChannel
    instance.eventChannel=eventChannel;
    
    //真实设置Handler
    [instance.eventChannel setStreamHandler:instance];
    
    //注册
    [registrar addMethodCallDelegate:instance channel:channel];
}

//执行
- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    //什么其他方法都没有实现
    result(FlutterMethodNotImplemented);
}

//初始化event
-(void)initFrameView{
    //获取根目录
    UIViewController* root=[[UIApplication sharedApplication].keyWindow rootViewController];
    //拿到最顶层的controller
    UIViewController *topController = [self _topViewController:root];
    //高度
    _height=topController.view.bounds.size.height;
    //宽度
    _width=topController.view.bounds.size.width;
    //位置位于最下方
    _frameView  = [[UIView alloc]initWithFrame:CGRectMake(0,
                                                          _height,
                                                          _width,
                                                          0)];
    //添加
    [topController.view addSubview:_frameView];
}

//释放
-(void)disposeFrameView{
    //移除
    [_frameView removeFromSuperview];
    //清空
    _frameView=nil;
}

//这里是获取整个应用的顶部Controller;
- (UIViewController *)_topViewController:(UIViewController *)vc {
    if ([vc isKindOfClass:[UINavigationController class]]) {
        return [self _topViewController:[(UINavigationController *)vc topViewController]];
    } else if ([vc isKindOfClass:[UITabBarController class]]) {
        return [self _topViewController:[(UITabBarController *)vc selectedViewController]];
    } else {
        return vc;
    }
    return nil;
}

//循环
-(void)timerAction:(id)data{
    //返回高度
    if(_frameView!=nil&&_eventSink!=nil){
        _eventSink([NSNumber numberWithDouble:_height-_frameView.layer.presentationLayer.frame.origin.y]);
    }
}


//监听显示
- (void)keyboardWillShowNotification:(NSNotification *)notification
{
    
    CGRect keyboardEndFrameWindow                         = [KeyboardabserverPlugin returnKeyBoardWindow:notification];
    
    double keyboardTransitionDuration                     = [KeyboardabserverPlugin returnKeyBoardDuration:notification];
    
    UIViewAnimationCurve keyboardTransitionAnimationCurve = [KeyboardabserverPlugin returnKeyBoardAnimationCurve:notification];
    
    NSTimer* _timerShow=[NSTimer timerWithTimeInterval:0.005
                                                target:self
                                              selector:@selector(timerAction:)
                                              userInfo:nil
                                               repeats:YES];
    
    [[NSRunLoop currentRunLoop] addTimer:_timerShow forMode:NSRunLoopCommonModes];
    
    __weak typeof(self) safeSelf=self;
    
    [UIView animateWithDuration:keyboardTransitionDuration
                          delay:0
                        options:(UIViewAnimationOptions)keyboardTransitionAnimationCurve << 16
                     animations:^{
        
        CGFloat  y                     = safeSelf.height;
        CGRect frame                   = CGRectMake(0, y,safeSelf.width, 0);
        frame.origin.y                -= keyboardEndFrameWindow.size.height;
        safeSelf.frameView.frame = frame;
        
    } completion:^(BOOL finished) {
        [self timerAction:nil];
        [_timerShow invalidate];
    }];
    
    
}

//监听隐藏
- (void)keyboardWillHideNotification:(NSNotification *)notification
{
    CGRect keyboardEndFrameWindow                         = [KeyboardabserverPlugin returnKeyBoardWindow:notification];
    
    double keyboardTransitionDuration                     = [KeyboardabserverPlugin returnKeyBoardDuration:notification];
    
    UIViewAnimationCurve keyboardTransitionAnimationCurve = [KeyboardabserverPlugin returnKeyBoardAnimationCurve:notification];
    
    NSTimer* _timerHide=[NSTimer timerWithTimeInterval:0.005
                                                target:self
                                              selector:@selector(timerAction:)
                                              userInfo:nil
                                               repeats:YES];
    
    [[NSRunLoop currentRunLoop] addTimer:_timerHide forMode:NSRunLoopCommonModes];
    
    __weak typeof(self) safeSelf=self;
    
    [UIView animateWithDuration:keyboardTransitionDuration
                          delay:0
                        options:(UIViewAnimationOptions)keyboardTransitionAnimationCurve << 16
                     animations:^{
        CGPoint center                   = safeSelf.frameView.center;
        center.y                        += keyboardEndFrameWindow.size.height;
        safeSelf.frameView.center                = center;
    } completion:^(BOOL finished) {
        [self timerAction:nil];
        [_timerHide invalidate];
    }];
}

+ (CGRect)returnKeyBoardWindow:(NSNotification *)notification{
    CGRect keyboardEndFrameWindow;
    [[notification.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] getValue: &keyboardEndFrameWindow];
    return keyboardEndFrameWindow;
}
+ (double)returnKeyBoardDuration:(NSNotification *)notification{
    double keyboardTransitionDuration;
    [[notification.userInfo valueForKey:UIKeyboardAnimationDurationUserInfoKey] getValue:&keyboardTransitionDuration];
    return keyboardTransitionDuration;
}
+ (UIViewAnimationCurve)returnKeyBoardAnimationCurve:(NSNotification *)notification{
    UIViewAnimationCurve keyboardTransitionAnimationCurve;
    [[notification.userInfo valueForKey:UIKeyboardAnimationCurveUserInfoKey] getValue:&keyboardTransitionAnimationCurve];
    return keyboardTransitionAnimationCurve;
}


#pragma mark - <FlutterStreamHandler>
// // 这个onListen是Flutter端开始监听这个channel时的回调，第二个参数 EventSink是用来传数据的载体。
- (FlutterError* _Nullable)onListenWithArguments:(id _Nullable)arguments
                                       eventSink:(FlutterEventSink)events {
    // 回调给flutter， 建议使用实例指向，因为该block可以使用多次
    _eventSink=events;
    //设置初始化
    [self initFrameView];
    //设置监听
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShowNotification:) name:UIKeyboardWillShowNotification object:nil];
    //设置监听
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHideNotification:) name:UIKeyboardWillHideNotification object:nil];
    //赋值参数
    return nil;
}

//flutter不再接收
- (FlutterError* _Nullable)onCancelWithArguments:(id _Nullable)arguments {
    //清空参数
    _eventSink=nil;
    //移除监听
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillShowNotification
                                                  object:nil];
    //设置监听
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillHideNotification
                                                  object:nil];
    //释放frameView
    [self disposeFrameView];
    //清空参数
    return nil;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    
}


@end
