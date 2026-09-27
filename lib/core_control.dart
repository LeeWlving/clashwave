import 'dart:async';
import 'dart:io';

import 'package:clash_for_flutter/app/utils/constants.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

class CoreControl {
  static const MethodChannel _channel = MethodChannel('io.qzz.wenyun/mihomo');
  static final _protocolUrls = StreamController<String>.broadcast();
  static const _lifecycle = MethodChannel('io.qzz.wenyun/core-lifecycle');
  static Directory? _desktopHomeDir;
  static Process? _desktopCore;

  static Stream<String> get protocolUrls => _protocolUrls.stream;

  // 初始化clash
  static void init() {
    if (Platform.isMacOS) {
      _lifecycle.setMethodCallHandler((call) async {
        if (call.method == 'shutdown') await shutdown();
      });
    }
    if (!Constants.isDesktop) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'protocolUrl' && call.arguments is String) {
          _protocolUrls.add(call.arguments as String);
        }
      });
      return;
    }
  }

  static Future<void> startVpn() {
    return _channel.invokeMethod('startVpn');
  }

  static Future<void> stopVpn() {
    return _channel.invokeMethod('stopVpn');
  }

  static Future<bool?> startService() {
    if (Constants.isDesktop) {
      return _startDesktopCore();
    }
    return _channel.invokeMethod<bool>('startService');
  }

  static Future<bool?> setConfig(File config) {
    if (Constants.isDesktop) {
      final home = _desktopHomeDir;
      if (home == null) return Future.value(false);
      return config
          .copy(path.join(home.path, 'config.yaml'))
          .then<bool>((_) => true);
    }
    return _channel.invokeMethod<bool>('setConfig', {"config": config.path});
  }

  static Future<bool?> setHomeDir(Directory dir) {
    if (Constants.isDesktop) {
      _desktopHomeDir = dir;
      return Future.value(true);
    }
    return _channel.invokeMethod<bool>('setHomeDir', {"dir": dir.path});
  }

  static Future<String?> startRust(String addr) {
    if (Constants.isDesktop) {
      return Future.value(addr);
    }
    return _channel.invokeMethod<String>('startRust', {"addr": addr});
  }

  static Future<bool?> verifyMMDB(String path) {
    if (Constants.isDesktop) {
      return Future<bool>.sync(() {
        final file = File(path);
        return file.existsSync() && file.lengthSync() > 0;
      });
    }
    return _channel.invokeMethod<bool>('verifyMMDB', {"path": path});
  }

  static Future<String?> getInitialProtocolUrl() {
    if (Constants.isDesktop) return Future.value();
    return _channel.invokeMethod<String>('getInitialUrl');
  }

  static Future<bool> _startDesktopCore() async {
    if (_desktopCore != null) return true;
    final home = _desktopHomeDir;
    if (home == null) return false;

    final executableName = Platform.isWindows ? 'mihomo.exe' : 'mihomo';
    final executable = File(
      path.join(File(Platform.resolvedExecutable).parent.path, executableName),
    );
    if (!executable.existsSync()) {
      throw StateError('Mihomo core not found: ${executable.path}');
    }

    final process = await Process.start(executable.path, [
      '-d',
      home.path,
      '-f',
      path.join(home.path, 'config.yaml'),
    ]);
    _desktopCore = process;
    process.stdout.transform(systemEncoding.decoder).listen((line) {
      if (line.trim().isNotEmpty) print('[mihomo] $line');
    });
    process.stderr.transform(systemEncoding.decoder).listen((line) {
      if (line.trim().isNotEmpty) print('[mihomo] $line');
    });
    process.exitCode.then((_) {
      if (identical(_desktopCore, process)) _desktopCore = null;
    });

    final exitedEarly = await Future.any<bool>([
      process.exitCode.then((_) => true),
      Future<bool>.delayed(const Duration(milliseconds: 800), () => false),
    ]);
    return !exitedEarly;
  }

  static Future<void> shutdown() async {
    final process = _desktopCore;
    _desktopCore = null;
    if (process == null) return;
    process.kill();
    await process.exitCode.timeout(
      const Duration(seconds: 3),
      onTimeout: () => -1,
    );
  }
}
