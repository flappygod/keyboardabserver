import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';

class Keyboardabserver {
  //设置
  static const MethodChannel _channel = const MethodChannel('keyboardabserver');

  //设置eventChannel
  static const EventChannel _eventChannel = EventChannel('keyboardabserver_event');

  //是否处于监听状态
  static bool _listenState = false;

  //监听列表
  static List<KeyboardAnimationListener> _listeners = [];

  //添加监听
  static void addKeyboardListener(KeyboardAnimationListener animationListener) {
    _listeners.add(animationListener);
    if (!_listenState) {
      _listenState = true;
      //注册用于和原生代码的持续回调
      Stream<double> stream = _eventChannel.receiveBroadcastStream().map((result) => result as double);
      //数据
      stream.listen((data) {
        for (int s = 0; s < _listeners.length; s++) {
          _listeners[s](data);
        }
      });
    }
  }

  //移除监听
  static void removeKeyboardListener(KeyboardAnimationListener animationListener) {
    _listeners.remove(animationListener);
  }
}

//监听键盘弹出收回
typedef KeyboardObserverListener = Function(double old, double height);

//监听键盘动画数值
typedef KeyboardAnimationListener = Function(double bottomInsets);

//监听
class KeyboardObserver extends StatefulWidget {
  //子类
  final Widget? child;

  //动画曲线
  final Curve? curveShow;

  //动画duration
  final Duration? durationShow;

  //动画曲线
  final Curve? curveHide;

  //动画duration
  final Duration? durationHide;

  //显示
  final KeyboardObserverListener? showListener;

  //隐藏的监听
  final KeyboardObserverListener? hideListener;

  //动画监听
  final KeyboardAnimationListener? animationListener;

  //子类
  KeyboardObserver({
    this.child,
    this.showListener,
    this.hideListener,
    this.curveShow,
    this.durationShow,
    this.curveHide,
    this.durationHide,
    this.animationListener,
  });

  @override
  State<StatefulWidget> createState() {
    return _KeyboardObserverState();
  }
}

//状态切换
class _KeyboardObserverState extends State<KeyboardObserver> with TickerProviderStateMixin {
  //创建globleKey
  GlobalKey _globalKey = new GlobalKey();

  //之前的bottom
  double _formerBottom = 0;

  //显示控制器
  late AnimationController _showAnimationController;

  //隐藏控制器
  late AnimationController _hideAnimationController;

  //之前的高度
  double _formerHeight = 0;

  //显示的监听
  late VoidCallback _showListener;

  //隐藏的监听
  late VoidCallback _hideListener;

  //显示动画
  Animation<double>? _showAnim;

  //显示动画
  Animation<double>? _hideAnim;

  //初始化状态
  void initState() {
    //初始化动画数据
    _initAnimation();
    //初始化之前的数据
    _initFormerData();
    super.initState();
  }

  //初始化动画
  void _initAnimation() {
    //苹果原生特殊处理
    if (Platform.isIOS && !kIsWeb) {
      //直接添加监听
      if (widget.animationListener != null) {
        Keyboardabserver.addKeyboardListener(widget.animationListener!);
      }
      return;
    }
    //显示的animation
    _showAnimationController = new AnimationController(duration: widget.durationShow ?? new Duration(milliseconds: 350), vsync: this);
    //隐藏的animation
    _hideAnimationController = new AnimationController(duration: widget.durationHide ?? new Duration(milliseconds: 350), vsync: this);
    //显示的监听
    _showListener = () {
      _formerHeight = _showAnim!.value;
      if (widget.animationListener != null) {
        widget.animationListener!(_formerHeight);
      }
    };
    //隐藏的监听
    _hideListener = () {
      _formerHeight = _hideAnim!.value;
      if (widget.animationListener != null) {
        widget.animationListener!(_formerHeight);
      }
    };
  }

  //初始化之前的数据
  void _initFormerData() {
    //绘制完成后确认当前的控件高度
    WidgetsBinding.instance!.addPostFrameCallback((callback) {
      //底部的距离
      if (_formerBottom == 0) {
        _formerBottom = MediaQuery.of(context).viewInsets.bottom;
      }
    });
  }

  //释放控制器
  void _disposeController() {
    //苹果原生特殊处理
    if (Platform.isIOS && !kIsWeb) {
      //移除监听
      if (widget.animationListener != null) {
        Keyboardabserver.removeKeyboardListener(widget.animationListener!);
      }
      return;
    }
    //其他方式都是通过键盘弹出来确定的
    _showAnimationController.dispose();
    _hideAnimationController.dispose();
  }

  //移除
  void dispose() {
    _disposeController();
    super.dispose();
  }

  //检查底部并进行通知
  Future<void> _checkBottomAndNotify() async {
    if (MediaQuery.of(context).viewInsets.bottom > _formerBottom) {
      double changed = MediaQuery.of(context).viewInsets.bottom - _formerBottom;
      if (widget.showListener != null) {
        widget.showListener!(_formerBottom, changed);
      }
      _showAnimation(_formerBottom, changed);
      _formerBottom = MediaQuery.of(context).viewInsets.bottom;
    } else if (MediaQuery.of(context).viewInsets.bottom < _formerBottom) {
      double changed = _formerBottom - MediaQuery.of(context).viewInsets.bottom;
      if (widget.hideListener != null) {
        widget.hideListener!(_formerBottom, changed);
      }
      _hideAnimation(_formerBottom, changed);
      _formerBottom = MediaQuery.of(context).viewInsets.bottom;
    }
  }

  //显示animation
  void _showAnimation(double _former, double changed) {
    //苹果原生特殊处理
    if (Platform.isIOS && !kIsWeb) {
      return;
    }
    if (_hideAnim != null) {
      _hideAnim!.removeListener(_hideListener);
    }
    if (_showAnim != null) {
      _showAnim!.removeListener(_showListener);
    }
    //停止之前的
    _hideAnimationController.stop();
    _showAnimationController.stop();
    _hideAnimationController.reset();
    _showAnimationController.reset();
    //显示
    _showAnim = new Tween<double>(begin: _formerHeight, end: _former + changed).animate(
      _showAnimationController,
    );
    _showAnim!.addListener(_showListener);
    //开启动画
    _showAnimationController.forward();
  }

  //隐藏animaiton
  void _hideAnimation(double _former, double changed) {
    //苹果原生特殊处理
    if (Platform.isIOS && !kIsWeb) {
      return;
    }
    if (_hideAnim != null) {
      _hideAnim!.removeListener(_hideListener);
    }
    if (_showAnim != null) {
      _showAnim!.removeListener(_showListener);
    }
    //停止之前的
    _hideAnimationController.stop();
    _showAnimationController.stop();
    _showAnimationController.reset();
    _hideAnimationController.reset();
    //显示
    _hideAnim = new Tween<double>(begin: _formerHeight, end: _former - changed).animate(
      _hideAnimationController,
    );
    _hideAnim!.addListener(_hideListener);
    //开启动画
    _hideAnimationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    _checkBottomAndNotify();
    return new Container(
      key: _globalKey,
      child: widget.child,
    );
  }
}
