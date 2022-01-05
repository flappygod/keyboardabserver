import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';

class KeyboardAbserverListenManager {
  //set channel
  static const MethodChannel _channel = MethodChannel('keyboardabserver');

  //eventChannel
  static const EventChannel _eventChannel = EventChannel('keyboardabserver_event');

  //listen state
  static bool _listenState = false;

  //listener
  static final List<KeyboardAnimationListener> _listeners = [];

  //add listener
  static void addKeyboardListener(KeyboardAnimationListener animationListener) {
    _listeners.add(animationListener);
    if (!_listenState) {
      _listenState = true;
      Stream<double> stream = _eventChannel.receiveBroadcastStream().map((result) => result as double);
      stream.listen((data) {
        for (int s = 0; s < _listeners.length; s++) {
          _listeners[s](data);
        }
      });
    }
  }

  //remove
  static void removeKeyboardListener(KeyboardAnimationListener animationListener) {
    _listeners.remove(animationListener);
  }
}

//listener
typedef KeyboardObserverListener = Function(double old, double height);

//animation listener
typedef KeyboardAnimationListener = Function(double bottomInsets);

//observer
class KeyboardObserver extends StatefulWidget {
  //child
  final Widget? child;

  //curve show
  final Curve? curveShow;

  //animation duration show
  final Duration? durationShow;

  //curve
  final Curve? curveHide;

  //animation duration hide
  final Duration? durationHide;

  //listener
  final KeyboardObserverListener? showListener;

  //hide listener
  final KeyboardObserverListener? hideListener;

  //animation listener
  final KeyboardAnimationListener? animationListener;

  //add key
  const KeyboardObserver({
    Key? key,
    this.child,
    this.showListener,
    this.hideListener,
    this.curveShow,
    this.durationShow,
    this.curveHide,
    this.durationHide,
    this.animationListener,
  }):super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _KeyboardObserverState();
  }
}

//state
class _KeyboardObserverState extends State<KeyboardObserver> with TickerProviderStateMixin {
  //create globle key
  final GlobalKey _globalKey = GlobalKey();

  //bottom
  double _formerBottom = 0;

  //show animation controller
  late AnimationController _showAnimationController;

  //hide  animation controller
  late AnimationController _hideAnimationController;

  //former height
  double _formerHeight = 0;

  //show listener
  late VoidCallback _showListener;

  //hide listener
  late VoidCallback _hideListener;

  //show anim
  Animation<double>? _showAnim;

  //hide anim
  Animation<double>? _hideAnim;

  //init state
  @override
  void initState() {
    _initAnimation();
    _initFormerData();
    super.initState();
  }

  //animation
  void _initAnimation() {
    //apple
    if (Platform.isIOS && !kIsWeb) {
      if (widget.animationListener != null) {
        KeyboardAbserverListenManager.addKeyboardListener(widget.animationListener!);
      }
      return;
    }
    _showAnimationController = AnimationController(duration: widget.durationShow ?? const Duration(milliseconds: 350), vsync: this);
    _hideAnimationController = AnimationController(duration: widget.durationHide ?? const Duration(milliseconds: 350), vsync: this);
    //show listener
    _showListener = () {
      _formerHeight = _showAnim!.value;
      if (widget.animationListener != null) {
        widget.animationListener!(_formerHeight);
      }
    };
    //hide listener
    _hideListener = () {
      _formerHeight = _hideAnim!.value;
      if (widget.animationListener != null) {
        widget.animationListener!(_formerHeight);
      }
    };
  }

  //init former data
  void _initFormerData() {
    //add post callback
    WidgetsBinding.instance!.addPostFrameCallback((callback) {
      if (_formerBottom == 0) {
        _formerBottom = MediaQuery.of(context).viewInsets.bottom;
      }
    });
  }

  //dispose
  void _disposeController() {
    if (Platform.isIOS && !kIsWeb) {
      if (widget.animationListener != null) {
        KeyboardAbserverListenManager.removeKeyboardListener(widget.animationListener!);
      }
      return;
    }
    _showAnimationController.dispose();
    _hideAnimationController.dispose();
  }

  //remove
  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  //check bottom and notify
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

  //show animation
  void _showAnimation(double _former, double changed) {
    //is ios
    if (Platform.isIOS && !kIsWeb) {
      return;
    }
    if (_hideAnim != null) {
      _hideAnim!.removeListener(_hideListener);
    }
    if (_showAnim != null) {
      _showAnim!.removeListener(_showListener);
    }
    //stop former
    _hideAnimationController.stop();
    _showAnimationController.stop();
    _hideAnimationController.reset();
    _showAnimationController.reset();
    //_showAnim
    _showAnim = Tween<double>(begin: _formerHeight, end: _former + changed).animate(
      _showAnimationController,
    );
    _showAnim!.addListener(_showListener);
    //start animation
    _showAnimationController.forward();
  }

  //hide anim
  void _hideAnimation(double _former, double changed) {
    //is ios
    if (Platform.isIOS && !kIsWeb) {
      return;
    }
    if (_hideAnim != null) {
      _hideAnim!.removeListener(_hideListener);
    }
    if (_showAnim != null) {
      _showAnim!.removeListener(_showListener);
    }
    //stop former
    _hideAnimationController.stop();
    _showAnimationController.stop();
    _showAnimationController.reset();
    _hideAnimationController.reset();
    //hide
    _hideAnim = Tween<double>(begin: _formerHeight, end: _former - changed).animate(
      _hideAnimationController,
    );
    _hideAnim!.addListener(_hideListener);
    //hide animation
    _hideAnimationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    _checkBottomAndNotify();
    return Container(
      key: _globalKey,
      child: widget.child,
    );
  }
}
