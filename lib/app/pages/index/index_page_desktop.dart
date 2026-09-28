import 'package:clash_for_flutter/app/component/drawer_component.dart';
import 'package:clash_for_flutter/app/pages/index/tray_controller.dart';
import 'package:clash_for_flutter/app/pages/router.dart';
import 'package:desktop_lifecycle/desktop_lifecycle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:window_manager/window_manager.dart';

class IndexDesktopPage extends StatefulWidget {
  const IndexDesktopPage({super.key});

  @override
  State<IndexDesktopPage> createState() => _IndexDesktopPageState();
}

class _IndexDesktopPageState extends State<IndexDesktopPage>
    with WindowListener, WidgetsBindingObserver {
  final _tray = Modular.get<TrayController>();
  final _lifeEvent = DesktopLifecycle.instance.isActive;

  final PageController _page = PageController();

  @override
  void initState() {
    super.initState();
    // 窗口监听
    windowManager.addListener(this);
    // 移动端前后台监听
    WidgetsBinding.instance.addObserver(this);
    // 桌面端前后台监听
    _lifeEvent.addListener(() => appListener(_lifeEvent.value));
    // 接管窗口的关闭按钮
    windowManager.setPreventClose(true);
    // 托盘初始化
    _tray.attachPageController(_page);
    _tray.init();
    Modular.to.navigate("/tab/home/");
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    WidgetsBinding.instance.removeObserver(this);
    _tray.detachPageController(_page);
    _page.dispose();
    super.dispose();
  }

  @override
  void onWindowClose() async {
    if (await windowManager.isPreventClose()) {
      windowManager.hide();
    }
  }

  @override
  void onWindowFocus() {
    setState(() {});
  }

  /// 处理在移动端前后台
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    appListener(state == AppLifecycleState.inactive);
  }

  /// 统一处理前后台改变
  void appListener(bool state) {
    if (state) {
      debugPrint("应用前台");
    } else {
      debugPrint("应用后台");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppDrawer(page: _page),
        Expanded(
          child: PageView.builder(
            controller: _page,
            itemCount: menu.size,
            onPageChanged: (i) =>
                Modular.to.navigate("/tab${menu.getPath(i)}/"),
            itemBuilder: (_, _) => const RouterOutlet(),
          ),
        ),
      ],
    );
  }
}
