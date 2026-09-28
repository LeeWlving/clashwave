import 'dart:async';

import 'package:asuka/asuka.dart';
import 'package:clash_for_flutter/app/bean/profile_url_bean.dart';
import 'package:clash_for_flutter/app/component/loading_component.dart';
import 'package:clash_for_flutter/app/pages/router.dart';
import 'package:clash_for_flutter/app/source/app_config.dart';
import 'package:clash_for_flutter/app/source/request.dart';
import 'package:clash_for_flutter/core_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class IndexMobilePage extends StatefulWidget {
  const IndexMobilePage({super.key});

  @override
  State<IndexMobilePage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexMobilePage>
    with WidgetsBindingObserver {
  static const _primaryPages = [0, 1, 3, 4];

  final _config = Modular.get<AppConfig>();
  final _request = Modular.get<Request>();
  final PageController _page = PageController();
  StreamSubscription<String>? _protocolSubscription;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _protocolSubscription = CoreControl.protocolUrls.listen(_onProtocolUrl);
    CoreControl.getInitialProtocolUrl().then((url) {
      if (url != null) _onProtocolUrl(url);
    });
    WidgetsBinding.instance.addObserver(this);
    Modular.to.navigate('/tab/home/');
  }

  @override
  void dispose() {
    _protocolSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _page.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('ClashWave lifecycle: ${state.name}');
  }

  void _onProtocolUrl(String url) {
    final uri = Uri.parse(Uri.decodeFull(url));
    if (uri.host != 'install-config') return;
    final subscribeUrl = uri.queryParameters['url'];
    if (subscribeUrl == null) {
      Asuka.showSnackBar(const SnackBar(content: Text('导入订阅链接有误')));
      return;
    }

    final profile = ProfileURL.emptyBean()
      ..url = subscribeUrl
      ..name = uri.queryParameters['name'] ?? '';
    final loading = Loading.builder();
    Asuka.addOverlay(loading);
    _request
        .getSubscribe(profile: profile, profilesDir: _config.profilesPath)
        .then((profile) {
          _config.setState(profiles: [..._config.profiles, profile]);
          Asuka.showSnackBar(const SnackBar(content: Text('导入成功')));
        })
        .catchError((error) {
          Asuka.showSnackBar(SnackBar(content: Text('导入异常：$error')));
        })
        .whenComplete(() {
          loading.remove();
          if (_page.hasClients) _page.jumpToPage(4);
        });
  }

  int get _navigationIndex {
    final primary = _primaryPages.indexOf(_pageIndex);
    return primary == -1 ? 4 : primary;
  }

  Future<void> _selectDestination(int index) async {
    if (index < _primaryPages.length) {
      _page.jumpToPage(_primaryPages[index]);
      return;
    }
    final target = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('更多', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ListTile(
              minTileHeight: 52,
              leading: const Icon(Icons.list_alt_rounded),
              title: const Text('日志'),
              subtitle: const Text('查看 Mihomo 运行记录'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.pop(context, 2),
            ),
            ListTile(
              minTileHeight: 52,
              leading: const Icon(Icons.settings_outlined),
              title: const Text('设置'),
              subtitle: const Text('端口、模式与内核服务'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.pop(context, 5),
            ),
          ],
        ),
      ),
    );
    if (target != null && mounted) _page.jumpToPage(target);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView.builder(
        controller: _page,
        itemCount: menu.size,
        onPageChanged: (index) {
          setState(() => _pageIndex = index);
          Modular.to.navigate('/tab${menu.getPath(index)}/');
        },
        itemBuilder: (_, _) => const RouterOutlet(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navigationIndex,
        onDestinationSelected: _selectDestination,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.cloud_outlined),
            selectedIcon: Icon(Icons.cloud_rounded),
            label: '代理',
          ),
          NavigationDestination(
            icon: Icon(Icons.link_outlined),
            selectedIcon: Icon(Icons.link_rounded),
            label: '连接',
          ),
          NavigationDestination(
            icon: Icon(Icons.layers_outlined),
            selectedIcon: Icon(Icons.layers_rounded),
            label: '订阅',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded),
            label: '更多',
          ),
        ],
      ),
    );
  }
}
