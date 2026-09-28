import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
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
  static bool _desktopPrivileged = false;

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

  static Future<bool> isVpnRunning() async {
    if (!Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>('isVpnRunning') ?? false;
  }

  static Future<bool?> startService() {
    if (Constants.isDesktop) {
      return _startDesktopCore();
    }
    return _channel.invokeMethod<bool>('startService');
  }

  static bool get isPrivilegedDesktopCore => _desktopPrivileged;

  /// Restarts the desktop core in a small elevated, GUI-lifetime-scoped
  /// supervisor. The Flutter process remains unprivileged and continues to
  /// communicate with Mihomo through its loopback REST/WebSocket controller.
  static Future<bool> ensurePrivilegedDesktopCore() async {
    if (!Constants.isDesktop || _desktopPrivileged) return false;
    final home = _desktopHomeDir;
    if (home == null) throw StateError('Mihomo home directory is not ready');
    final executable = _desktopExecutable();
    if (!executable.existsSync()) {
      throw StateError('Mihomo core not found: ${executable.path}');
    }

    await _stopDirectCore();
    try {
      await _launchPrivilegedSupervisor(executable, home);
      if (!await _waitForController()) {
        throw StateError('提权后的 Mihomo 未能连接到本地控制端口');
      }
      _desktopPrivileged = true;
      return true;
    } catch (_) {
      _desktopPrivileged = false;
      await _startDesktopCore();
      rethrow;
    }
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

    if (_desktopPrivileged && await _controllerReachable()) return true;
    final executable = _desktopExecutable();
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
      if (line.trim().isNotEmpty) {
        developer.log(line, name: 'ClashWave.mihomo');
      }
    });
    process.stderr.transform(systemEncoding.decoder).listen((line) {
      if (line.trim().isNotEmpty) {
        developer.log(line, name: 'ClashWave.mihomo', level: 900);
      }
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
    if (_desktopPrivileged) {
      // The elevated supervisor watches this GUI process and terminates Mihomo
      // immediately after the GUI exits. A standard user process intentionally
      // does not receive a handle capable of killing an elevated process.
      return;
    }
    await _stopDirectCore();
  }

  static File _desktopExecutable() {
    final executableName = Platform.isWindows ? 'mihomo.exe' : 'mihomo';
    return File(
      path.join(File(Platform.resolvedExecutable).parent.path, executableName),
    );
  }

  static Future<void> _stopDirectCore() async {
    final process = _desktopCore;
    _desktopCore = null;
    if (process == null) return;
    process.kill();
    await process.exitCode.timeout(
      const Duration(seconds: 3),
      onTimeout: () => -1,
    );
  }

  static Future<void> _launchPrivilegedSupervisor(
    File executable,
    Directory home,
  ) async {
    final config = path.join(home.path, 'config.yaml');
    final guiPid = pid;
    if (Platform.isWindows) {
      String quote(String value) => value.replaceAll("'", "''");
      final inner =
          '''
\$core = Start-Process -FilePath '${quote(executable.path)}' -ArgumentList @('-d','${quote(home.path)}','-f','${quote(config)}') -WindowStyle Hidden -PassThru
try {
  while (Get-Process -Id $guiPid -ErrorAction SilentlyContinue) { Start-Sleep -Seconds 2 }
} finally {
  Stop-Process -Id \$core.Id -Force -ErrorAction SilentlyContinue
}
''';
      final utf16le = <int>[
        for (final unit in inner.codeUnits) ...[unit & 0xff, unit >> 8],
      ];
      final encoded = base64.encode(utf16le);
      final outer =
          "\$ErrorActionPreference='Stop'; "
          "Start-Process -FilePath 'powershell.exe' -Verb RunAs "
          "-WindowStyle Hidden -ArgumentList @('-NoProfile','-NonInteractive',"
          "'-EncodedCommand','$encoded')";
      final result = await Process.run('powershell.exe', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        outer,
      ]);
      if (result.exitCode != 0) {
        throw StateError('Windows 提权被取消或启动失败');
      }
      return;
    }

    final script =
        '${_shellQuote(executable.path)} -d ${_shellQuote(home.path)} '
        '-f ${_shellQuote(config)} >/dev/null 2>&1 & core=\$!; '
        'while kill -0 $guiPid 2>/dev/null; do sleep 2; done; '
        'kill \$core 2>/dev/null || true';
    if (Platform.isMacOS) {
      final command = 'nohup sh -c ${_shellQuote(script)} >/dev/null 2>&1 &';
      final appleScript = command
          .replaceAll('\\', '\\\\')
          .replaceAll('"', '\\"');
      final result = await Process.run('osascript', [
        '-e',
        'do shell script "$appleScript" with administrator privileges',
      ]);
      if (result.exitCode != 0) {
        throw StateError('macOS 管理员授权被取消或启动失败');
      }
      return;
    }

    await Process.start('pkexec', [
      'sh',
      '-c',
      script,
    ], mode: ProcessStartMode.detached);
  }

  static String _shellQuote(String value) =>
      "'${value.replaceAll("'", "'\\''")}'";

  static Future<bool> _waitForController() async {
    for (var attempt = 0; attempt < 40; attempt++) {
      if (await _controllerReachable()) return true;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return false;
  }

  static Future<bool> _controllerReachable() async {
    final parts = Constants.rustAddr.split(':');
    final port = parts.length == 2 ? int.tryParse(parts.last) : null;
    if (port == null) return false;
    try {
      final socket = await Socket.connect(
        Constants.localhost,
        port,
        timeout: const Duration(milliseconds: 300),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }
}
