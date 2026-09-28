import 'dart:async';
import 'package:clash_for_flutter/app/bean/net_speed.dart';
import 'package:clash_for_flutter/app/component/brand_mark.dart';
import 'package:clash_for_flutter/app/pages/router.dart';
import 'package:clash_for_flutter/app/source/request.dart';
import 'package:clash_for_flutter/app/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key, required this.page});

  final PageController page;

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final _request = Modular.get<Request>();
  NetSpeed _speed = NetSpeed();
  String _clashVersion = '—';
  StreamSubscription? _subscription;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.page.addListener(_syncSelection);
    _subscription = _request.traffic().listen((event) {
      if (mounted) setState(() => _speed = event ?? NetSpeed());
    });
    _request.getClashVersion().then((value) {
      if (mounted) setState(() => _clashVersion = value ?? _clashVersion);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    widget.page.removeListener(_syncSelection);
    super.dispose();
  }

  void _syncSelection() {
    final page = widget.page.page;
    if (page == null) return;
    final next = page.round();
    if (next != _selectedIndex && mounted) {
      setState(() => _selectedIndex = next);
    }
  }

  void _goTo(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
    widget.page.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 760;
    return Container(
      width: compact ? 76 : 232,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(right: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            _BrandHeader(compact: compact),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: menu.size,
                itemBuilder: (context, index) {
                  final item = menu.menuList[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _NavigationItem(
                      label: item.title,
                      icon: item.icon,
                      selected: index == _selectedIndex,
                      compact: compact,
                      onTap: () => _goTo(index),
                    ),
                  );
                },
              ),
            ),
            _TrafficFooter(
              speed: _speed,
              clashVersion: _clashVersion,
              compact: compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = compact
        ? const Center(child: ClashWaveMark(size: 42))
        : Row(
            children: [
              const ClashWaveMark(size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ClashWave',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '安静地连接世界',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 14),
      child: content,
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final Widget icon;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected ? scheme.primary : scheme.onSurfaceVariant;
    final item = Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 46),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 3,
                  height: selected ? 22 : 0,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                SizedBox(width: compact ? 9 : 12),
                IconTheme(
                  data: IconThemeData(color: foreground, size: 21),
                  child: icon,
                ),
                if (!compact) ...[
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return compact ? Tooltip(message: label, child: item) : item;
  }
}

class _TrafficFooter extends StatelessWidget {
  const _TrafficFooter({
    required this.speed,
    required this.clashVersion,
    required this.compact,
  });

  final NetSpeed speed;
  final String clashVersion;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final valueStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          children: [
            Tooltip(
              message: '上传 ${dataformat(speed.up)}/s',
              child: Icon(
                Icons.north_east_rounded,
                size: 18,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            Tooltip(
              message: '下载 ${dataformat(speed.down)}/s',
              child: Icon(
                Icons.south_west_rounded,
                size: 18,
                color: scheme.primary,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          _TrafficLine(
            icon: Icons.north_east_rounded,
            label: '上传',
            value: '${dataformat(speed.up)}/s',
            style: valueStyle,
          ),
          const SizedBox(height: 7),
          _TrafficLine(
            icon: Icons.south_west_rounded,
            label: '下载',
            value: '${dataformat(speed.down)}/s',
            style: valueStyle,
          ),
          const SizedBox(height: 10),
          Text(
            'Mihomo $clashVersion',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _TrafficLine extends StatelessWidget {
  const _TrafficLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.style,
  });

  final IconData icon;
  final String label;
  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 7),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const Spacer(),
        Text(value, style: style),
      ],
    );
  }
}
