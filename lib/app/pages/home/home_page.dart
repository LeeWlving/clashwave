import 'package:asuka/asuka.dart';
import 'package:clash_for_flutter/app/component/brand_mark.dart';
import 'package:clash_for_flutter/app/component/sys_app_bar.dart';
import 'package:clash_for_flutter/app/exceptions/message_exception.dart';
import 'package:clash_for_flutter/app/enum/type_enum.dart';
import 'package:clash_for_flutter/app/source/app_config.dart';
import 'package:clash_for_flutter/app/source/core_config.dart';
import 'package:clash_for_flutter/app/utils/constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AppConfig _config = Modular.get<AppConfig>();
  final CoreConfig _core = Modular.get<CoreConfig>();
  bool _loading = false;

  bool get _isOpen => _config.tunIf ? _core.tunEnable : _config.systemProxy;

  Future<void> _toggleConnection() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      if (_config.tunIf) {
        _core.tunEnable ? await _core.closeTun() : await _core.openTun();
      } else {
        _config.systemProxy
            ? await _config.closeProxy()
            : await _config.openProxy();
      }
    } catch (error, stack) {
      debugPrint('切换代理失败：$error\n$stack');
      final detail = switch (error) {
        MessageException() => error.getMessage(),
        DioException() => error.message ?? error.toString(),
        PlatformException() => error.message ?? error.code,
        _ => error.toString(),
      };
      Asuka.showSnackBar(SnackBar(content: Text('切换代理失败：$detail')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeTun(bool value) {
    if (value) {
      Asuka.showSnackBar(
        const SnackBar(
          content: Text('首次开启 TUN 时系统会请求授权，ClashWave 界面仍以普通权限运行。'),
        ),
      );
    }
    _config.setState(tunIf: value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SysAppBar(title: Text('概览')),
      body: Observer(
        builder: (_) {
          final isOpen = _isOpen;
          final mode = _core.clash.mode?.value ?? 'Rule';
          final profile = _config.active?.name.trim();
          return LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 680;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  compact ? 16 : 32,
                  compact ? 12 : 28,
                  compact ? 16 : 32,
                  28,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 880),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ConnectionHero(
                          connected: isOpen,
                          loading: _loading,
                          onPressed: _toggleConnection,
                        ),
                        const SizedBox(height: 18),
                        _QuickFacts(
                          compact: compact,
                          transport: _config.tunIf ? 'TUN 模式' : '系统代理',
                          mode: _modeLabel(mode),
                          profile: profile == null || profile.isEmpty
                              ? '尚未选择'
                              : profile,
                        ),
                        if (Constants.isDesktop) ...[
                          const SizedBox(height: 18),
                          Card(
                            child: SwitchListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 6,
                              ),
                              secondary: const Icon(Icons.route_outlined),
                              title: const Text('使用 TUN 模式'),
                              subtitle: const Text('接管更多应用流量；开启时可能需要安装特权内核服务'),
                              value: _config.tunIf,
                              onChanged: _loading ? null : _changeTun,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _modeLabel(String mode) => switch (mode.toLowerCase()) {
    'global' => '全局',
    'direct' => '直连',
    _ => '规则',
  };
}

class _ConnectionHero extends StatelessWidget {
  const _ConnectionHero({
    required this.connected,
    required this.loading,
    required this.onPressed,
  });

  final bool connected;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      label: connected ? '流量接管已开启' : '流量接管未开启',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
        decoration: BoxDecoration(
          color: connected ? scheme.primaryContainer : scheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: connected
                ? scheme.primary.withAlpha(60)
                : scheme.outlineVariant,
          ),
        ),
        child: Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: ClashWaveMark(
                key: ValueKey(connected),
                size: 112,
                active: connected,
                showBackground: false,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              connected ? '流量接管已开启' : '准备连接',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              connected ? 'ClashWave 正在按当前规则处理网络请求' : '开启后，网络请求将交由 Mihomo 处理',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 176,
              child: connected
                  ? FilledButton.tonalIcon(
                      onPressed: loading ? null : onPressed,
                      icon: loading
                          ? const _ButtonProgress()
                          : const Icon(Icons.stop_circle_outlined),
                      label: const Text('停止接管'),
                    )
                  : FilledButton.icon(
                      onPressed: loading ? null : onPressed,
                      icon: loading
                          ? const _ButtonProgress()
                          : const Icon(Icons.power_settings_new_rounded),
                      label: const Text('开始接管'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ButtonProgress extends StatelessWidget {
  const _ButtonProgress();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

class _QuickFacts extends StatelessWidget {
  const _QuickFacts({
    required this.compact,
    required this.transport,
    required this.mode,
    required this.profile,
  });

  final bool compact;
  final String transport;
  final String mode;
  final String profile;

  @override
  Widget build(BuildContext context) {
    final items = [
      _FactData(Icons.route_outlined, '接管方式', transport),
      _FactData(Icons.tune_rounded, '代理模式', mode),
      _FactData(Icons.layers_outlined, '当前订阅', profile),
    ];
    if (compact) {
      return Card(
        child: Column(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              _FactTile(data: items[index]),
              if (index != items.length - 1)
                const Divider(indent: 56, endIndent: 18),
            ],
          ],
        ),
      );
    }
    return Row(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          Expanded(child: _FactCard(data: items[index])),
          if (index != items.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _FactData {
  const _FactData(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;
}

class _FactTile extends StatelessWidget {
  const _FactTile({required this.data});

  final _FactData data;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 58,
      leading: Icon(data.icon, color: Theme.of(context).colorScheme.primary),
      title: Text(data.label),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180),
        child: Text(
          data.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ),
    );
  }
}

class _FactCard extends StatelessWidget {
  const _FactCard({required this.data});

  final _FactData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(data.icon, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
