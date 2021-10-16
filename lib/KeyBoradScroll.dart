import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';

typedef TextFieldWrapperListener = void Function(FocusNode focusNode);

class TextFieldWrapper {
  //通过控件的焦点和key构造
  TextFieldWrapper.fromKey({
    required this.focusNode,
    required this.focusKey,
    this.more = 0,
  }) {
    //回调
    _focusDelegateListener = () {
      //当前的焦点变化
      if (_focusChangedListener != null) {
        _focusChangedListener!(focusNode);
      }
    };
    focusNode.addListener(_focusDelegateListener!);
  }

  //焦点变化的代理监听
  VoidCallback? _focusDelegateListener;

  //焦点变化的外部监听，用于通知
  TextFieldWrapperListener? _focusChangedListener;

  //key
  GlobalKey focusKey;

  //焦点
  FocusNode focusNode;

  //底部
  double _bottom = 0;

  //more
  double more;

  //刷新底部距离
  void _refreshBottomHeight(double offsetHeight) {
    //同时刷新距离吧
    if (focusKey.currentContext != null) {
      //找到
      final RenderBox renderBox = focusKey.currentContext!.findRenderObject() as RenderBox;
      //正下方底部距离
      var offset = renderBox.localToGlobal(Offset(0.0, renderBox.size.height));
      //底部距离
      _bottom = MediaQuery.of(focusKey.currentContext!).size.height - offset.dy;
    }
  }

  //获取底部距离
  double getBottom() {
    return _bottom - more;
  }
}

//控制器
class KeyBroadScrollController {
  //默认为零
  double _nowValue = 0;

  //当前的高度
  double _formerEnd = 0;

  //输入框的wrapper
  List<TextFieldWrapper> _wrappers = [];

  //监听
  TextFieldWrapperListener? _focusChangedListener;

  //设置焦点切换的监听
  void setFocusListener(TextFieldWrapperListener listener) {
    _focusChangedListener = listener;
    for (int s = 0; s < _wrappers.length; s++) {
      _wrappers[s]._focusChangedListener = _focusChangedListener;
    }
  }

  //添加
  void addTextFieldWrapper(TextFieldWrapper wrapper) {
    if (!_wrappers.contains(wrapper)) {
      wrapper._focusChangedListener = _focusChangedListener;
      _wrappers.add(wrapper);
    }
  }

  //移除
  void removeTextFieldWrapper(TextFieldWrapper wrapper) {
    if (_wrappers.contains(wrapper)) {
      _wrappers.remove(wrapper);
    }
  }

  //刷新高度
  void refreshHeights() {
    for (int s = 0; s < _wrappers.length; s++) {
      _wrappers[s]._refreshBottomHeight(_nowValue);
    }
  }

  //获取当前选中的控件和底部最小的距离
  double getBottomNeedMargin() {
    double? smaller;
    for (int s = 0; s < _wrappers.length; s++) {
      if (smaller == null || smaller > _wrappers[s].getBottom()) {
        if (_wrappers[s].focusNode.hasFocus) {
          smaller = _wrappers[s].getBottom();
        }
      }
    }
    return smaller ?? 0;
  }
}

//类型
enum KeyBroadScrollType {
  //只针对底部
  fitJustBottom,
  //针对每个text
  fitEveryText,
}

//创建
class KeyBroadScroll extends StatefulWidget {
  //关闭
  final bool closeWhenTap;

  //child
  final Widget child;

  //控制器
  final KeyBroadScrollController controller;

  //类型
  final KeyBroadScrollType scrollType;

  const KeyBroadScroll({
    Key? key,
    required this.controller,
    required this.child,
    this.closeWhenTap: false,
    this.scrollType = KeyBroadScrollType.fitEveryText,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _KeyBroadScrollState();
  }
}

//创建
class _KeyBroadScrollState extends State<KeyBroadScroll> with TickerProviderStateMixin, WidgetsBindingObserver {
  //全局key
  GlobalKey _globalKey = new GlobalKey();

  //控制器
  AnimationController? outController;

  //控制器
  AnimationController? inController;

  //动画
  Animation<double>? inAnimation;

  //动画
  Animation<double>? outAnimation;

  //进入
  VoidCallback? _inListener;

  //消失
  VoidCallback? _outListener;

  //默认的
  VoidCallback? _defaultHeightCallback;

  //初始化
  void initState() {
    //状态初始化
    super.initState();
    //初始化controller
    initOutAnim();
    //初始化controller
    initInAnim();
    //默认callback
    _defaultHeightCallback = () {
      _changeDefaultHeight();
    };
    //绘制完成后确认当前的控件高度
    WidgetsBinding.instance!.addPostFrameCallback((callback) {
      _initController();
    });
    //监听
    WidgetsBinding.instance!.addObserver(this);
  }

  //初始化控制器
  void _initController() {
    //以每个EditText为准
    if (widget.scrollType == KeyBroadScrollType.fitEveryText) {
      //设置监听
      widget.controller.setFocusListener((focusNode) {
        if (focusNode.hasFocus) {
          if (kIsWeb || !Platform.isIOS) {
            WidgetsBinding.instance!.addPostFrameCallback((callback) {
              _changeUserControlHeight();
            });
          }
        }
      });
      widget.controller.refreshHeights();
    }
    //以底部为标准
    if (widget.scrollType == KeyBroadScrollType.fitJustBottom) {
      if (_defaultHeightCallback != null) {
        registerFrameListener(_defaultHeightCallback!);
      }
    }
  }

  //是否增加了
  static bool initFlag = false;

  //回调列表
  static List<VoidCallback> callbacks = [];

  //初始化键盘弹出监听
  static void registerFrameListener(VoidCallback callback) {
    WidgetsBinding widgetsBinding = WidgetsBinding.instance!;
    callbacks.add(callback);
    if (!initFlag) {
      widgetsBinding.addPersistentFrameCallback((callback) {
        for (int s = 0; s < callbacks.length; s++) {
          callbacks[s]();
        }
      });
    }
  }

  //移除
  static void unRegisterFrameListener(VoidCallback callback) {
    callbacks.remove(callback);
  }

  //修改高度
  void _changeDefaultHeight() {
    //如果底部的高度和之前的不一致
    if (widget.controller._formerEnd != MediaQuery.of(context).viewInsets.bottom) {
      //设置新的值
      double newValue = MediaQuery.of(context).viewInsets.bottom;
      //设置之前的
      widget.controller._formerEnd = newValue;
      //如果之前的比新的大，代表是缩回操作
      if (widget.controller._nowValue > newValue) {
        _createOutAnim(widget.controller._nowValue, newValue);
        outController!.reset();
        outController!.forward();
      }
      //代表顶出去的操作
      else {
        _createInAnim(widget.controller._nowValue, newValue);
        inController!.reset();
        inController!.forward();
      }
    }
  }

//更新
  void didUpdateWidget(KeyBroadScroll old) {
    super.didUpdateWidget(old);
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (widget.scrollType == KeyBroadScrollType.fitEveryText) {
      WidgetsBinding.instance!.addPostFrameCallback((callback) {
        _changeUserControlHeight();
      });
    }
  }

//释放
  void dispose() {
    //移除
    WidgetsBinding.instance!.removeObserver(this);
    //移除
    if (_defaultHeightCallback != null) {
      //释放
      unRegisterFrameListener(_defaultHeightCallback!);
      //移除
      _defaultHeightCallback = null;
    }
    //释放
    outController?.dispose();
    //释放
    inController?.dispose();
    super.dispose();
  }

//初始化退出动画
  void initOutAnim() {
    _outListener = () {
      if (outAnimation != null) {
        widget.controller._nowValue = outAnimation!.value;
        if (mounted) setState(() {});
      }
    };
    //控制器创建
    outController = new AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
  }

//初始化开始动画
  void initInAnim() {
    _inListener = () {
      if (inAnimation != null) {
        widget.controller._nowValue = inAnimation!.value;
        if (mounted) setState(() {});
      }
    };
    //控制器创建
    inController = new AnimationController(
      duration: const Duration(
        milliseconds: 250,
      ),
      vsync: this,
    );
  }

  //通过用户控制，改变
  void _changeUserControlHeight() {
    //返回
    if (mounted) {
      //底部距离
      double bottomNearest = widget.controller.getBottomNeedMargin();
      //底部的距离
      double bottomMargin = MediaQuery.of(context).viewInsets.bottom;
      //我们需要向上移动的距离
      double bottomNeed = (bottomMargin - bottomNearest) < 0 ? 0 : (bottomMargin - bottomNearest);
      //之前的
      if (widget.controller._formerEnd != bottomNeed) {
        //底部需要移动的距离
        double newValue = bottomNeed;
        //设置之前的
        widget.controller._formerEnd = newValue;
        //如果之前的比新的大，代表是缩回操作
        if (widget.controller._nowValue > newValue) {
          _createOutAnim(widget.controller._nowValue, newValue);
          outController!.reset();
          outController!.forward();
        }
        //代表顶出去的操作
        else {
          _createInAnim(widget.controller._nowValue, newValue);
          inController!.reset();
          inController!.forward();
        }
      }
    }
  }

//通过新的值创建缩回的动画
  void _createOutAnim(double former, double newValue) {
    inAnimation?.removeListener(_inListener!);
    outAnimation?.removeListener(_outListener!);
    outAnimation = new ReverseTween(
      new Tween(
        begin: newValue,
        end: former,
      ),
    ).animate(
      CurvedAnimation(
        parent: outController!,
        curve: Curves.easeInOut,
      ),
    );
    outAnimation!.addListener(_outListener!);
  }

//通过新的值创建弹出动画
  void _createInAnim(double former, double newValue) {
    inAnimation?.removeListener(_inListener!);
    outAnimation?.removeListener(_outListener!);
    inAnimation = new Tween(
      begin: former,
      end: newValue,
    ).animate(
      CurvedAnimation(
        parent: inController!,
        curve: Curves.easeInOut,
      ),
    );
    //添加监听
    inAnimation!.addListener(_inListener!);
  }

  @override
  Widget build(BuildContext context) {
    return new GestureDetector(
      onVerticalDragEnd: (data) {
        FocusScope.of(context).requestFocus(FocusNode());
      },
      onTap: () {
        FocusScope.of(context).requestFocus(FocusNode());
      },
      child: new Transform.translate(
        key: _globalKey,
        offset: new Offset(0, -widget.controller._nowValue),
        child: widget.child,
      ),
    );
  }
}
