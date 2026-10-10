import 'dart:async';
import 'dart:io';

import 'package:asuka/asuka.dart';
import 'package:clash_for_flutter/app/component/sys_app_bar.dart';
import 'package:clash_for_flutter/app/exceptions/message_exception.dart';
import 'package:clash_for_flutter/app/source/app_config.dart';
import 'package:clash_for_flutter/app/source/core_config.dart';
import 'package:clash_for_flutter/app/source/logs_subscription.dart';
import 'package:clash_for_flutter/app/source/request.dart';
import 'package:clash_for_flutter/app/utils/constants.dart';
import 'package:clash_for_flutter/core_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:dio/dio.dart';
import 'package:window_manager/window_manager.dart';

class InitPage extends StatefulWidget {
  const InitPage({super.key});

  @override
  State<InitPage> createState() => _InitPageState();
}

class _InitPageState extends State<InitPage> {
  final _config = Modular.get<AppConfig>();
  final _core = Modular.get<CoreConfig>();
  final _request = Modular.get<Request>();
  final _logs = Modular.get<LogsSubscription>();
  double? _loadingProgress;
  bool _isLoading = true;
  bool _skipDataDownloads = false;
  CancelToken? _downloadCancellation;
  String _loadingLabel = '正在准备 Mihomo 数据文件';

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _downloadCancellation?.cancel('页面已关闭');
    super.dispose();
  }

  void _skipDownloads() {
    _skipDataDownloads = true;
    _downloadCancellation?.cancel('用户跳过下载');
  }

  Future<void> _init() async {
    await Future(() async {
          if (!await _request.hello().then(
            (res) => res.statusCode == HttpStatus.ok,
          )) {
            throw MessageException("无法连接到内核，请尝试重启应用");
          }

          await _config.init();

          final mmdb = File("${Constants.homeDir.path}${Constants.mmdb}");
          await _ensureCoreData(
            file: mmdb,
            url: _config.clashForMe.mmdbUrl,
            label: 'Country.mmdb',
            isValid: () async =>
                await CoreControl.verifyMMDB(mmdb.path) ?? false,
          );

          // Modern Mihomo configurations may reference GEOSITE in rules or
          // DNS policies. Pre-downloading it avoids a configuration reload 400
          // when the core cannot reach GitHub directly during initialization.
          final geosite = File("${Constants.homeDir.path}${Constants.geosite}");
          await _ensureCoreData(
            file: geosite,
            url: _config.clashForMe.geositeUrl,
            label: 'GeoSite.dat',
            isValid: () async =>
                geosite.existsSync() && geosite.lengthSync() > 0,
          );

          await _core.asyncConfig();

          // 已经开启tun直接跳转
          if (_config.tunIf && _core.tunEnable) {
            return;
          }

          // A broken subscription must not prevent the application from
          // opening. Keep the bootstrap config active so it can be updated or
          // replaced from the profile page.
          try {
            if (!_skipDataDownloads) await _config.asyncProfile();
          } catch (error) {
            if (Platform.isMacOS) {
              await windowManager.show();
              await windowManager.focus();
            }
            Asuka.showSnackBar(
              SnackBar(content: Text('订阅配置加载失败，请更新或更换订阅：$error')),
            );
          }
        })
        .then((value) async {
          await _core.asyncConfig();
          if (!mounted) return;
          _logs.startSubLogs(); // 启动日志订阅
          Modular.to.navigate("/tab");
        })
        .onError((error, stackTrace) async {
          if (!mounted) return;
          if (Platform.isMacOS) {
            await windowManager.show();
            await windowManager.focus();
          }
          if (!mounted) return;
          setState(() => _isLoading = false);
          Modular.to.navigate("/error");
          Asuka.showSnackBar(SnackBar(content: Text(error.toString())));
        });
  }

  Future<void> _ensureCoreData({
    required File file,
    required String url,
    required String label,
    required Future<bool> Function() isValid,
  }) async {
    if (_skipDataDownloads || !mounted || await isValid()) return;
    final cancellation = CancelToken();
    _downloadCancellation = cancellation;
    // Never treat an interrupted download as a valid database on next launch.
    final partial = File('${file.path}.part');

    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadingProgress = null;
        _loadingLabel = '正在下载 $label';
      });
    }

    try {
      await _request
          .downFile(
            urlPath: url,
            savePath: partial.path,
            cancelToken: cancellation,
            onReceiveProgress: (received, total) {
              if (mounted && total > 0) {
                setState(() => _loadingProgress = received / total);
              }
            },
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              cancellation.cancel('下载超时');
              throw TimeoutException('$label 下载超过 30 秒');
            },
          );
      if (!cancellation.isCancelled) await partial.rename(file.path);
    } catch (error) {
      final skipped = _skipDataDownloads;
      _skipDataDownloads = true;
      if (mounted && !skipped) {
        Asuka.showSnackBar(
          const SnackBar(content: Text('规则数据暂时无法下载，先进入应用。需要这些数据的规则暂不可用。')),
        );
      }
    } finally {
      _downloadCancellation = null;
      if (mounted) {
        setState(() {
          _loadingProgress = null;
          _loadingLabel = '正在进入应用…';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? LoadingWidget(
            value: _loadingProgress,
            label: _loadingLabel,
            onSkip: _downloadCancellation == null ? null : _skipDownloads,
          )
        : const RouterOutlet();
  }
}

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({
    super.key,
    required this.value,
    required this.label,
    this.onSkip,
  });

  final double? value;
  final String label;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: const SysAppBar(title: Text("ClashWave")),
      body: Center(
        child: SizedBox(
          height: 200,
          child: Flex(
            direction: Axis.vertical,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(
                width: size.width * 0.6,
                child: LinearProgressIndicator(
                  value: value,
                  backgroundColor: Colors.black12,
                  minHeight: 10,
                ),
              ),
              Text(label),
              if (onSkip != null)
                TextButton(onPressed: onSkip, child: const Text('跳过，进入应用')),
            ],
          ),
        ),
      ),
    );
  }
}
