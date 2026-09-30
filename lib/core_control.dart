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

  static bool get supportsDesktopService =>
      Platform.isWindows || Platform.isMacOS;

  static Future<bool> isDesktopServiceInstalled() async {
    if (Platform.isWindows) {
      final helper = _windowsServiceExecutable();
      if (!helper.existsSync()) return false;
      final result = await Process.run(helper.path, ['--is-installed']);
      return result.exitCode == 0;
    }
    if (Platform.isMacOS) {
      return File(_macLaunchDaemonPath).existsSync();
    }
    return false;
  }

  /// Moves Windows/macOS to an OS-managed service. Linux retains the scoped
  /// pkexec supervisor until a native service implementation is added.
  static Future<bool> ensurePrivilegedDesktopCore() async {
    if (!Constants.isDesktop || _desktopPrivileged) return false;
    final home = _desktopHomeDir;
    if (home == null) throw StateError('Mihomo home directory is not ready');
    final executable = _desktopExecutable();
    if (!executable.existsSync()) {
      throw StateError('Mihomo core not found: ${executable.path}');
    }

    if (supportsDesktopService) {
      await installDesktopService();
      return true;
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

  /// Installs and starts an OS-managed privileged core. Installation is the
  /// only operation that triggers a UAC/macOS administrator prompt.
  static Future<void> installDesktopService() async {
    if (!supportsDesktopService) {
      throw UnsupportedError('当前平台不支持持久化内核服务');
    }
    final home = _desktopHomeDir;
    if (home == null) throw StateError('Mihomo home directory is not ready');
    final core = _desktopExecutable();
    if (!core.existsSync()) {
      throw StateError('Mihomo core not found: ${core.path}');
    }
    final config = File(path.join(home.path, 'config.yaml'));
    if (!config.existsSync()) throw StateError('Mihomo config is not ready');
    _validateProtectedInstallation(core);

    await _stopDirectCore();
    try {
      if (Platform.isWindows) {
        final helper = _windowsServiceExecutable();
        if (!helper.existsSync()) {
          throw StateError('Windows service helper not found: ${helper.path}');
        }
        final exitCode = await _runWindowsElevated(helper, [
          '--install',
          core.path,
          home.path,
          config.path,
        ]);
        if (exitCode != 0) {
          throw StateError('Windows 内核服务安装失败（代码 $exitCode）');
        }
      } else {
        await _installMacLaunchDaemon(core, home, config);
      }
      if (!await _waitForController()) {
        throw StateError('特权内核服务未能连接到本机控制端口');
      }
      _desktopPrivileged = true;
    } catch (_) {
      _desktopPrivileged = false;
      await _startDesktopCore();
      rethrow;
    }
  }

  static Future<void> uninstallDesktopService() async {
    if (!supportsDesktopService) return;
    if (Platform.isWindows) {
      final helper = _windowsServiceExecutable();
      if (helper.existsSync()) {
        final exitCode = await _runWindowsElevated(helper, ['--uninstall']);
        if (exitCode != 0) {
          throw StateError('Windows 内核服务卸载失败（代码 $exitCode）');
        }
      }
    } else {
      await _uninstallMacLaunchDaemon();
    }
    _desktopPrivileged = false;
    await _startDesktopCore();
    if (!await _waitForController()) {
      throw StateError('普通权限 Mihomo 内核重新启动失败');
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

  /// Calls libmihomo's native action API on Android.
  ///
  /// The embedded Android library intentionally does not expose the Clash
  /// REST controller. Desktop builds continue to use that controller.
  static Future<dynamic> invokeAction(String method, [dynamic data]) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Mihomo actions are only available on Android');
    }
    final raw = await _channel.invokeMethod<String>('invokeAction', {
      'method': method,
      'data': data,
    });
    if (raw == null || raw.isEmpty) {
      throw StateError('Mihomo action $method returned no response');
    }
    final response = jsonDecode(raw);
    if (response is! Map) {
      throw StateError('Invalid Mihomo action response for $method');
    }
    if (response['code'] != 0) {
      throw StateError('${response['data'] ?? 'Mihomo action $method failed'}');
    }
    return response['data'];
  }

  static Future<bool> _startDesktopCore() async {
    if (_desktopCore != null) return true;
    final home = _desktopHomeDir;
    if (home == null) return false;

    if (supportsDesktopService && await isDesktopServiceInstalled()) {
      if (Platform.isWindows && !await _controllerReachable()) {
        final helper = _windowsServiceExecutable();
        final result = await Process.run(helper.path, ['--start']);
        if (result.exitCode != 0) {
          throw StateError('Windows 内核服务启动失败（代码 ${result.exitCode}）');
        }
      }
      if (!await _waitForController()) {
        throw StateError('已安装的内核服务没有响应，请重新安装服务');
      }
      _desktopPrivileged = true;
      return true;
    }
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
      // An installed service intentionally survives GUI shutdown. Linux's
      // supervisor observes the GUI process and cleans up its Mihomo child.
      return;
    }
    await _stopDirectCore();
  }

  /// Restarts Mihomo without restarting the Flutter GUI.
  ///
  /// An installed Windows/macOS service is restarted through its native
  /// service manager. Otherwise the GUI-owned child process is replaced.
  static Future<void> restartService() async {
    if (!Constants.isDesktop) {
      throw UnsupportedError('当前平台不支持从托盘重启内核');
    }

    if (supportsDesktopService && await isDesktopServiceInstalled()) {
      if (Platform.isWindows) {
        final helper = _windowsServiceExecutable();
        if (!helper.existsSync()) {
          throw StateError('Windows service helper not found: ${helper.path}');
        }
        final stopped = await Process.run(helper.path, ['--stop']);
        if (stopped.exitCode != 0) {
          throw StateError('Windows 内核服务停止失败（代码 ${stopped.exitCode}）');
        }
        final started = await Process.run(helper.path, ['--start']);
        if (started.exitCode != 0) {
          throw StateError('Windows 内核服务启动失败（代码 ${started.exitCode}）');
        }
      } else {
        await _runMacElevated(
          '/bin/launchctl kickstart -k system/$_macLaunchDaemonLabel',
          'macOS 内核服务重启失败',
        );
      }
      if (!await _waitForController()) {
        throw StateError('重启后无法连接 Mihomo 控制接口');
      }
      _desktopPrivileged = true;
      return;
    }

    await _stopDirectCore();
    if (!await _startDesktopCore() || !await _waitForController()) {
      throw StateError('Mihomo 内核重启失败');
    }
  }

  static File _desktopExecutable() {
    final executableName = Platform.isWindows ? 'mihomo.exe' : 'mihomo';
    return File(
      path.join(File(Platform.resolvedExecutable).parent.path, executableName),
    );
  }

  static File _windowsServiceExecutable() => File(
    path.join(
      File(Platform.resolvedExecutable).parent.path,
      'clashwave_service.exe',
    ),
  );

  static void _validateProtectedInstallation(File core) {
    final appDirectory = core.parent.absolute.path;
    if (Platform.isWindows) {
      final roots = [
        Platform.environment['ProgramFiles'],
        Platform.environment['ProgramFiles(x86)'],
      ].whereType<String>().map((value) => path.normalize(value).toLowerCase());
      final normalized = path.normalize(appDirectory).toLowerCase();
      if (!roots.any(
        (root) => normalized == root || path.isWithin(root, normalized),
      )) {
        throw StateError('为避免提权风险，请先用安装包装到 Program Files，再安装内核服务');
      }
      return;
    }
    if (Platform.isMacOS &&
        appDirectory != '/Applications' &&
        !path.isWithin('/Applications', appDirectory)) {
      throw StateError('为避免提权风险，请先将 ClashWave.app 移入 /Applications');
    }
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

  static const _macLaunchDaemonLabel = 'io.qzz.wenyun.clashwave-core';
  static const _macLaunchDaemonPath =
      '/Library/LaunchDaemons/$_macLaunchDaemonLabel.plist';

  static Future<int> _runWindowsElevated(
    File executable,
    List<String> arguments,
  ) async {
    String quote(String value) => value.replaceAll("'", "''");
    final argumentList = arguments
        .map((value) => "'${quote(value)}'")
        .join(',');
    final command =
        "\$process = Start-Process -FilePath '${quote(executable.path)}' "
        "-Verb RunAs -WindowStyle Hidden -ArgumentList @($argumentList) "
        "-Wait -PassThru; exit \$process.ExitCode";
    final utf16le = <int>[
      for (final unit in command.codeUnits) ...[unit & 0xff, unit >> 8],
    ];
    final result = await Process.run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-EncodedCommand',
      base64.encode(utf16le),
    ]);
    return result.exitCode;
  }

  static Future<void> _installMacLaunchDaemon(
    File core,
    Directory home,
    File config,
  ) async {
    String xml(String value) => value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
    final source = File(path.join(home.path, '.clashwave-core.plist'));
    await source.writeAsString('''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>$_macLaunchDaemonLabel</string>
<key>ProgramArguments</key><array>
<string>${xml(core.path)}</string><string>-d</string><string>${xml(home.path)}</string>
<string>-f</string><string>${xml(config.path)}</string>
</array>
<key>WorkingDirectory</key><string>${xml(home.path)}</string>
<key>RunAtLoad</key><true/><key>KeepAlive</key><true/>
<key>ProcessType</key><string>Interactive</string>
</dict></plist>
''', flush: true);
    final command =
        '/bin/launchctl bootout system/$_macLaunchDaemonLabel >/dev/null 2>&1 || true; '
        '/bin/cp ${_shellQuote(source.path)} ${_shellQuote(_macLaunchDaemonPath)}; '
        '/usr/sbin/chown root:wheel ${_shellQuote(_macLaunchDaemonPath)}; '
        '/bin/chmod 644 ${_shellQuote(_macLaunchDaemonPath)}; '
        '/bin/launchctl bootstrap system ${_shellQuote(_macLaunchDaemonPath)}; '
        '/bin/launchctl enable system/$_macLaunchDaemonLabel; '
        '/bin/launchctl kickstart -k system/$_macLaunchDaemonLabel';
    await _runMacElevated(command, 'macOS 内核服务安装失败');
  }

  static Future<void> _uninstallMacLaunchDaemon() async {
    final home = _desktopHomeDir;
    final uid = (await Process.run('/usr/bin/id', [
      '-u',
    ])).stdout.toString().trim();
    final gid = (await Process.run('/usr/bin/id', [
      '-g',
    ])).stdout.toString().trim();
    final command =
        '/bin/launchctl bootout system/$_macLaunchDaemonLabel >/dev/null 2>&1 || true; '
        '/bin/rm -f ${_shellQuote(_macLaunchDaemonPath)}'
        '${home != null && int.tryParse(uid) != null && int.tryParse(gid) != null ? '; /usr/sbin/chown -R $uid:$gid ${_shellQuote(home.path)}' : ''}';
    await _runMacElevated(command, 'macOS 内核服务卸载失败');
  }

  static Future<void> _runMacElevated(String command, String error) async {
    final appleScript = command.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
    final result = await Process.run('osascript', [
      '-e',
      'do shell script "$appleScript" with administrator privileges',
    ]);
    if (result.exitCode != 0) throw StateError(error);
  }

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
    final client = HttpClient()..findProxy = (_) => 'DIRECT';
    try {
      final request = await client
          .getUrl(Uri.parse('http://${Constants.rustAddr}/version'))
          .timeout(const Duration(milliseconds: 500));
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${Constants.controllerSecret}',
      );
      final response = await request.close().timeout(
        const Duration(milliseconds: 500),
      );
      await response.drain<void>();
      return response.statusCode == HttpStatus.ok;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }
}
