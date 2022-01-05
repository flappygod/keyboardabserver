import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';

typedef TextFieldWrapperListener = void Function(FocusNode focusNode);

class TextFieldWrapper {
  TextFieldWrapper.fromKey({
    required this.focusNode,
    required this.focusKey,
    this.more = 0,
  }) {
    _focusDelegateListener = () {
      if (_focusChangedListener != null) {
        _focusChangedListener!(focusNode);
      }
    };
    focusNode.addListener(_focusDelegateListener!);
  }

  //focus delegate
  VoidCallback? _focusDelegateListener;

  //focus change listener
  TextFieldWrapperListener? _focusChangedListener;

  //key
  GlobalKey focusKey;

  //focus
  FocusNode focusNode;

  //bottom
  double _bottom = 0;

  //more
  double more;

  //refresh height
  void _refreshBottomHeight(double offsetHeight) {
    if (focusKey.currentContext != null) {
      final RenderBox renderBox = focusKey.currentContext!.findRenderObject() as RenderBox;
      var offset = renderBox.localToGlobal(Offset(0.0, renderBox.size.height));
      _bottom = MediaQuery.of(focusKey.currentContext!).size.height - offset.dy;
    }
  }

  //get bottom
  double getBottom() {
    return _bottom - more;
  }
}

//controller
class KeyBroadScrollController {
  double _nowValue = 0;

  double _formerEnd = 0;

  //wrapper
  final List<TextFieldWrapper> _wrappers = [];

  //listener
  TextFieldWrapperListener? _focusChangedListener;

  //set focus listener
  void setFocusListener(TextFieldWrapperListener listener) {
    _focusChangedListener = listener;
    for (int s = 0; s < _wrappers.length; s++) {
      _wrappers[s]._focusChangedListener = _focusChangedListener;
    }
  }

  //add text field wrapper
  void addTextFieldWrapper(TextFieldWrapper wrapper) {
    if (!_wrappers.contains(wrapper)) {
      wrapper._focusChangedListener = _focusChangedListener;
      _wrappers.add(wrapper);
    }
  }

  //remove text field wrapper
  void removeTextFieldWrapper(TextFieldWrapper wrapper) {
    if (_wrappers.contains(wrapper)) {
      _wrappers.remove(wrapper);
    }
  }

  //refresh height
  void refreshHeights() {
    for (int s = 0; s < _wrappers.length; s++) {
      _wrappers[s]._refreshBottomHeight(_nowValue);
    }
  }

  //get bottom margin
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

//type
enum KeyBroadScrollType {
  //just bottom
  fitJustBottom,
  //each text
  fitEveryText,
}

//KeyBroadScroll widget
class KeyBroadScroll extends StatefulWidget {
  //close when tap
  final bool closeWhenTap;

  //child
  final Widget child;

  //controller
  final KeyBroadScrollController controller;

  //type
  final KeyBroadScrollType scrollType;

  const KeyBroadScroll({
    Key? key,
    required this.controller,
    required this.child,
    this.closeWhenTap=false,
    this.scrollType = KeyBroadScrollType.fitEveryText,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _KeyBroadScrollState();
  }
}

//state
class _KeyBroadScrollState extends State<KeyBroadScroll> with TickerProviderStateMixin, WidgetsBindingObserver {

  //out animation
  AnimationController? outController;

  //int animation
  AnimationController? inController;

  //out animation
  Animation<double>? inAnimation;

  //int animation
  Animation<double>? outAnimation;

  //in anim listener
  VoidCallback? _inListener;

  //out anim listener
  VoidCallback? _outListener;

  //default height
  VoidCallback? _defaultHeightCallback;

  @override
  void initState() {
    super.initState();
    initOutAnim();
    initInAnim();
    _defaultHeightCallback = () {
      _changeDefaultHeight();
    };
    WidgetsBinding.instance!.addPostFrameCallback((callback) {
      _initController();
    });
    WidgetsBinding.instance!.addObserver(this);
  }

  //init controller
  void _initController() {
    if (widget.scrollType == KeyBroadScrollType.fitEveryText) {
      //set listener
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
    //bottom type
    if (widget.scrollType == KeyBroadScrollType.fitJustBottom) {
      if (_defaultHeightCallback != null) {
        registerFrameListener(_defaultHeightCallback!);
      }
    }
  }

  //is init or not
  static bool initFlag = false;

  //callbacks
  static List<VoidCallback> callbacks = [];

  //register
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

  //remove
  static void unRegisterFrameListener(VoidCallback callback) {
    callbacks.remove(callback);
  }

  void _changeDefaultHeight() {
    if (widget.controller._formerEnd != MediaQuery.of(context).viewInsets.bottom) {
      double newValue = MediaQuery.of(context).viewInsets.bottom;
      widget.controller._formerEnd = newValue;
      //contract
      if (widget.controller._nowValue > newValue) {
        _createOutAnim(widget.controller._nowValue, newValue);
        outController!.reset();
        outController!.forward();
      }
      //show out
      else {
        _createInAnim(widget.controller._nowValue, newValue);
        inController!.reset();
        inController!.forward();
      }
    }
  }


  @override
  void didUpdateWidget(KeyBroadScroll old) {
    super.didUpdateWidget(old);
    widget.controller.refreshHeights();
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

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    if (_defaultHeightCallback != null) {
      unRegisterFrameListener(_defaultHeightCallback!);
      _defaultHeightCallback = null;
    }
    outController?.dispose();
    inController?.dispose();
    super.dispose();
  }


  //out anim
  void initOutAnim() {
    _outListener = () {
      if (outAnimation != null) {
        widget.controller._nowValue = outAnimation!.value;
        if (mounted) setState(() {});
      }
    };
    outController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
  }

  //in anim
  void initInAnim() {
    _inListener = () {
      if (inAnimation != null) {
        widget.controller._nowValue = inAnimation!.value;
        if (mounted) setState(() {});
      }
    };
    inController = AnimationController(
      duration: const Duration(
        milliseconds: 250,
      ),
      vsync: this,
    );
  }

  //text focused height change
  void _changeUserControlHeight() {
    if (mounted) {
      double bottomNearest = widget.controller.getBottomNeedMargin();
      double bottomMargin = MediaQuery.of(context).viewInsets.bottom;
      double bottomNeed = (bottomMargin - bottomNearest) < 0 ? 0 : (bottomMargin - bottomNearest);
      if (widget.controller._formerEnd != bottomNeed) {
        double newValue = bottomNeed;
        widget.controller._formerEnd = newValue;
        if (widget.controller._nowValue > newValue) {
          _createOutAnim(widget.controller._nowValue, newValue);
          outController!.reset();
          outController!.forward();
        }
        else {
          _createInAnim(widget.controller._nowValue, newValue);
          inController!.reset();
          inController!.forward();
        }
      }
    }
  }

  void _createOutAnim(double former, double newValue) {
    inAnimation?.removeListener(_inListener!);
    outAnimation?.removeListener(_outListener!);
    outAnimation = ReverseTween(
      Tween(
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

  void _createInAnim(double former, double newValue) {
    inAnimation?.removeListener(_inListener!);
    outAnimation?.removeListener(_outListener!);
    inAnimation = Tween(
      begin: former,
      end: newValue,
    ).animate(
      CurvedAnimation(
        parent: inController!,
        curve: Curves.easeInOut,
      ),
    );
    inAnimation!.addListener(_inListener!);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: (data) {
        FocusScope.of(context).requestFocus(FocusNode());
      },
      onTap: () {
        FocusScope.of(context).requestFocus(FocusNode());
      },
      child: Transform.translate(
        offset: Offset(0, -widget.controller._nowValue),
        child: widget.child,
      ),
    );
  }
}
