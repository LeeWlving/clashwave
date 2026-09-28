import 'dart:async';
import 'dart:collection';

import 'package:clash_for_flutter/app/bean/log_bean.dart';
import 'package:clash_for_flutter/app/enum/type_enum.dart';
import 'package:clash_for_flutter/app/source/core_config.dart';
import 'package:clash_for_flutter/app/source/request.dart';
import 'package:clash_for_flutter/app/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:mobx/mobx.dart';

/// 日志订阅
class LogsSubscription extends ChangeNotifier implements Disposable {
  final _core = Modular.get<CoreConfig>();
  final _request = Modular.get<Request>();
  final Queue<LogData> _logQueue = Queue<LogData>();
  StreamSubscription? _subscription;
  ReactionDisposer? _levelReaction;

  List<LogData> get logList => _logQueue.toList();

  @override
  void dispose() {
    _levelReaction?.call();
    _subscription?.cancel();
    super.dispose();
  }

  void startSubLogs() {
    _levelReaction ??= reaction(
      (_) => _core.clash.logLevel ?? LogLevel.info,
      (_) => reconnect(),
      fireImmediately: true,
    );
  }

  void reconnect() {
    _subscription?.cancel();
    final level = _core.clash.logLevel ?? LogLevel.info;
    _subscription = _request.logs(level).listen((event) {
      if (event == null) return;
      if (_logQueue.length >= Constants.logsCapacity) {
        _logQueue.removeFirst();
      }
      _logQueue.add(event);
      notifyListeners();
    });
  }

  void clearLogs() {
    _logQueue.clear();
    notifyListeners();
  }
}
