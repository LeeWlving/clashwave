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
  double _loadingProgress = 0;
  bool _isLoading = false;
  String _loadingLabel = '正在准备 Mihomo 数据文件';

  @override
  void initState() {
    _init();
    super.initState();
  }

  Future<void> _init() async {
    await Future(() async {
          if (!await _request.hello().then(
            (res) => res.statusCode == HttpStatus.ok,
          )) {
            throw MessageException("无法连接到内核，请尝试重启应用");
          }

          _core.init();
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
            url: DefaultConfigValue.geositeUrl,
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
            await _config.asyncProfile();
          } catch (error) {
            Asuka.showSnackBar(
              SnackBar(content: Text('订阅配置加载失败，请更新或更换订阅：$error')),
            );
          }
        })
        .then((value) async {
          await _core.asyncConfig();
          _logs.startSubLogs(); // 启动日志订阅
          Modular.to.navigate("/tab");
        })
        .onError((error, stackTrace) {
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
    if (await isValid()) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadingProgress = 0;
        _loadingLabel = '正在下载 $label';
      });
    }

    try {
      await _request.downFile(
        urlPath: url,
        savePath: file.path,
        onReceiveProgress: (received, total) {
          if (mounted && total > 0) {
            setState(() => _loadingProgress = received / total);
          }
        },
      );
    } catch (error) {
      Asuka.showSnackBar(SnackBar(content: Text('$label 下载失败，可稍后重试：$error')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? LoadingWidget(value: _loadingProgress, label: _loadingLabel)
        : const RouterOutlet();
  }
}

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key, required this.value, required this.label});

  final double value;
  final String label;

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
            ],
          ),
        ),
      ),
    );
  }
}
