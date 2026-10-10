import 'package:clash_for_flutter/app/bean/group_bean.dart';
import 'package:clash_for_flutter/app/bean/profile_base_bean.dart';
import 'package:clash_for_flutter/app/bean/profile_url_bean.dart';
import 'package:clash_for_flutter/app/bean/proxies_bean.dart';
import 'package:clash_for_flutter/app/bean/proxy_bean.dart';
import 'package:clash_for_flutter/app/enum/type_enum.dart';
import 'package:system_tray/system_tray.dart';

/// Pure snapshot-to-menu mapping, shared by all desktop platforms.
class TrayMenus {
  const TrayMenus._();

  static SubMenu subscriptions({
    required List<ProfileBase> profiles,
    required String? selectedFile,
    required void Function(String file) onSelect,
    required void Function(ProfileURL profile) onUpdate,
    required void Function() onManage,
    List<MenuItemBase> actions = const [],
  }) {
    final active = profiles.whereType<ProfileURL>().where(
      (profile) => profile.file == selectedFile,
    );
    return SubMenu(
      label: '订阅 / 配置',
      children: [
        if (profiles.isEmpty) MenuItemLabel(label: '暂无配置', enabled: false),
        for (final profile in profiles)
          MenuItemCheckbox(
            label: profile.name.isEmpty ? profile.file : profile.name,
            checked: profile.file == selectedFile,
            onClicked: (_) => onSelect(profile.file),
          ),
        MenuSeparator(),
        if (active.isNotEmpty)
          MenuItemLabel(
            label: '更新当前订阅',
            onClicked: (_) => onUpdate(active.first),
          ),
        ...actions,
        MenuSeparator(),
        MenuItemLabel(label: '在仪表板管理…', onClicked: (_) => onManage()),
      ],
    );
  }

  /// Match ClashX's root-level group menus, preserving configuration order.
  static List<MenuItemBase> proxyGroups({
    required Proxies? snapshot,
    required Mode mode,
    required void Function(String group, String node) onSelect,
    required void Function(Group group) onTest,
    bool unavailable = false,
    bool testing = false,
    bool sortByDelay = false,
    Map<String, int?> delays = const {},
  }) {
    if (unavailable) {
      return [MenuItemLabel(label: '无法读取代理，请检查内核状态', enabled: false)];
    }
    final proxies = snapshot?.proxies ?? const <String, dynamic>{};
    final global = proxies['GLOBAL'];
    final ordered = <String>{
      if (global is Group) ...global.all,
      ...proxies.keys,
    };
    final groups = [
      if (mode == Mode.Global && global is Group) global,
      for (final name in ordered)
        if (name != 'GLOBAL' && proxies[name] is Group) proxies[name] as Group,
    ];
    if (groups.isEmpty) {
      return [MenuItemLabel(label: '暂无代理组，请先导入配置', enabled: false)];
    }
    return [
      for (final group in groups)
        SubMenu(
          label: group.type == GroupType.LoadBalance
              ? '${group.name} → 负载均衡'
              : '${group.name} → ${group.now}',
          children: [
            MenuItemLabel(
              label: testing ? '正在测速…' : '测试本组延迟',
              enabled: !testing,
              onClicked: (_) => onTest(group),
            ),
            MenuSeparator(),
            if (group.type != GroupType.Selector)
              MenuItemLabel(
                label: group.type == GroupType.LoadBalance
                    ? '负载均衡（由内核分配）'
                    : '自动选择（${group.type.value}）',
                enabled: false,
              ),
            for (final node in orderedNodes(group, snapshot, delays, sortByDelay))
              MenuItemCheckbox(
                label: nodeLabel(node, snapshot, delays),
                checked: group.type != GroupType.LoadBalance && group.now == node,
                enabled: group.type == GroupType.Selector,
                onClicked: (_) => onSelect(group.name, node),
              ),
          ],
        ),
    ];
  }

  static int? nodeDelay(String name, Proxies? snapshot, Map<String, int?> delays) {
    if (delays.containsKey(name)) return delays[name];
    final item = snapshot?.proxies[name];
    final history = item is Proxy ? item.history : (item is Group ? item.history : null);
    if (history == null || history.isEmpty) return null;
    return history.last.delay;
  }

  static String nodeLabel(String name, Proxies? snapshot, Map<String, int?> delays) {
    if (name == 'DIRECT' || name == 'REJECT' || name == 'REJECT-DROP' || name == 'PASS') {
      return name;
    }
    final delay = nodeDelay(name, snapshot, delays);
    if (delay == null && !delays.containsKey(name)) return '$name · 未测速';
    return '$name · ${delay != null && delay > 0 ? '$delay ms' : '超时'}';
  }

  static List<String> orderedNodes(
    Group group, Proxies? snapshot, Map<String, int?> delays, bool sort,
  ) {
    final nodes = group.all.toList();
    if (!sort) return nodes;
    final order = {for (var i = 0; i < nodes.length; i++) nodes[i]: i};
    int rank(String name) {
      final delay = nodeDelay(name, snapshot, delays);
      return delay != null && delay > 0 ? delay : 0x7fffffff;
    }
    nodes.sort((a, b) {
      final result = rank(a).compareTo(rank(b));
      return result != 0 ? result : order[a]!.compareTo(order[b]!);
    });
    return nodes;
  }
}
