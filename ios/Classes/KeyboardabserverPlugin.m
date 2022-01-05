#import "KeyboardabserverPlugin.h"

@interface KeyboardabserverPlugin ()<FlutterStreamHandler>

//channel
@property(nonatomic,weak) FlutterEventChannel* eventChannel;

//eventSink
@property(nonatomic,strong) FlutterEventSink eventSink;

//frameView
@property(nonatomic,strong) UIView* frameView;

//height
@property(nonatomic,assign) double height;

//width
@property(nonatomic,assign) double width;

@end


@implementation KeyboardabserverPlugin


+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"keyboardabserver"
                                     binaryMessenger:[registrar messenger]];
    
    //create eventChannel
    FlutterEventChannel* eventChannel=[FlutterEventChannel eventChannelWithName:@"keyboardabserver_event"
                                                                binaryMessenger:[registrar messenger]];
    //init
    KeyboardabserverPlugin* instance = [[KeyboardabserverPlugin alloc] init];
    
    //set eventChannel
    instance.eventChannel=eventChannel;
    
    //set Handler
    [instance.eventChannel setStreamHandler:instance];
    
    //set delegate
    [registrar addMethodCallDelegate:instance channel:channel];
}


- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    result(FlutterMethodNotImplemented);
}

//init frame view
-(void)initFrameView{
    //get root controller
    UIViewController* root=[[UIApplication sharedApplication].keyWindow rootViewController];
    //top controller
    UIViewController *topController = [self _topViewController:root];
    //height
    _height=topController.view.bounds.size.height;
    //widht
    _width=topController.view.bounds.size.width;
    //create frame view
    _frameView  = [[UIView alloc]initWithFrame:CGRectMake(0,
                                                          _height,
                                                          _width,
                                                          0)];
    //add frame view
    [topController.view addSubview:_frameView];
}

//disposeFrameView
-(void)disposeFrameView{
    [_frameView removeFromSuperview];
    _frameView=nil;
}

//get top
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

//stream
-(void)timerAction:(id)data{
    if(_frameView!=nil&&_eventSink!=nil){
        _eventSink([NSNumber numberWithDouble:_height-_frameView.layer.presentationLayer.frame.origin.y]);
    }
}


//keyboard notifications
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

//hide keyboard notifications
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
- (FlutterError* _Nullable)onListenWithArguments:(id _Nullable)arguments
                                       eventSink:(FlutterEventSink)events {
    _eventSink=events;
    [self initFrameView];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShowNotification:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHideNotification:) name:UIKeyboardWillHideNotification object:nil];
    return nil;
}


- (FlutterError* _Nullable)onCancelWithArguments:(id _Nullable)arguments {
    _eventSink=nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillShowNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillHideNotification
                                                  object:nil];
    [self disposeFrameView];
    return nil;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    
}


@end
