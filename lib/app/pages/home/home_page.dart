import 'package:asuka/asuka.dart';
import 'package:clash_for_flutter/app/component/sys_app_bar.dart';
import 'package:clash_for_flutter/app/exceptions/message_exception.dart';
import 'package:clash_for_flutter/app/source/app_config.dart';
import 'package:clash_for_flutter/app/source/core_config.dart';
import 'package:clash_for_flutter/app/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

const btnSize = Size(200, 70);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AppConfig _config = Modular.get<AppConfig>();
  final CoreConfig _core = Modular.get<CoreConfig>();
  bool _loading = false;

  click() {
    setState(() => _loading = true);
    Future(() {
          if (_config.tunIf) {
            if (_core.tunEnable) {
              return _core.closeTun();
            } else {
              return _core.openTun();
            }
          } else {
            if (_config.systemProxy) {
              return _config.closeProxy();
            } else {
              return _config.openProxy();
            }
          }
        })
        .catchError((Object e, StackTrace stack) {
          debugPrint('切换代理失败：$e\n$stack');
          if (e is MessageException) {
            Asuka.showSnackBar(SnackBar(content: Text(e.getMessage())));
          } else {
            final detail = e is DioException
                ? e.message ?? e.toString()
                : e is PlatformException
                ? e.message ?? e.code
                : e.toString();
            Asuka.showSnackBar(SnackBar(content: Text('切换代理失败：$detail')));
          }
        })
        .then((_) {
          if (mounted) setState(() => _loading = false);
        });
  }

  changeTun(bool? tunIf) {
    if (tunIf ?? false) {
      Asuka.showSnackBar(
        const SnackBar(content: Text("首次开启 TUN 时系统会请求管理员授权，应用界面仍以普通权限运行")),
      );
    }
    _config.setState(tunIf: tunIf);
  }

  get idOpen {
    if (_config.tunIf) {
      return _core.tunEnable;
    } else {
      return _config.systemProxy;
    }
  }

  Widget get _openButton {
    if (_loading) {
      return const LoadingButton();
    }
    return Observer(
      builder: (_) {
        if (idOpen) {
          return OffButton(onTap: click);
        } else {
          return OnButton(onTap: click);
        }
      },
    );
  }

  Widget get _switch {
    if (Constants.isDesktop) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Tun模式:"),
          Observer(
            builder: (_) => Switch(value: _config.tunIf, onChanged: changeTun),
          ),
        ],
      );
    }
    return Container();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SysAppBar(title: Text("ClashWave")),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [_openButton, _switch],
      ),
    );
  }
}

class OnButton extends StatelessWidget {
  final Function() onTap;

  const OnButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    var themeData = Theme.of(context);
    return Card(
      color: Colors.white54,
      child: SizedBox.fromSize(
        size: btnSize,
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.flight_takeoff_rounded,
                size: 36,
                color: themeData.primaryTextTheme.headlineMedium?.color,
              ),
              Container(
                padding: const EdgeInsets.only(left: 10),
                child: Text(
                  "开启",
                  style: themeData.primaryTextTheme.headlineMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OffButton extends StatelessWidget {
  final Function() onTap;

  const OffButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    var themeData = Theme.of(context);
    return Card(
      color: themeData.primaryColor,
      child: SizedBox.fromSize(
        size: btnSize,
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.flight_land_rounded,
                size: 36,
                color: themeData.primaryTextTheme.headlineMedium?.color,
              ),
              Container(
                padding: const EdgeInsets.only(left: 10),
                child: Text(
                  "关闭",
                  style: themeData.primaryTextTheme.headlineMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoadingButton extends StatelessWidget {
  const LoadingButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white54,
      child: SizedBox.fromSize(
        size: btnSize,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 5)),
      ),
    );
  }
}
