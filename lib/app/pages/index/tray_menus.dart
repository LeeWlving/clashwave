import 'package:clash_for_flutter/app/bean/group_bean.dart';
import 'package:clash_for_flutter/app/bean/profile_base_bean.dart';
import 'package:clash_for_flutter/app/bean/profile_url_bean.dart';
import 'package:clash_for_flutter/app/bean/proxies_bean.dart';
import 'package:clash_for_flutter/app/enum/type_enum.dart';
import 'package:system_tray/system_tray.dart';

/// Menu contents are built from snapshots; opening a menu refreshes the core
/// snapshot so changes made in the dashboard are reflected in the menu bar.
class TrayMenus {
  const TrayMenus._();

  static SubMenu subscriptions({
    required List<ProfileBase> profiles,
    required String? selectedFile,
    required void Function(String file) onSelect,
    required void Function(ProfileURL profile) onUpdate,
    required void Function() onManage,
  }) {
    final active = profiles.whereType<ProfileURL>().where(
      (profile) => profile.file == selectedFile,
    );
    return SubMenu(
      label: '订阅',
      children: [
        if (profiles.isEmpty)
          MenuItemLabel(label: '暂无订阅', enabled: false),
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
        MenuItemLabel(label: '管理订阅…', onClicked: (_) => onManage()),
      ],
    );
  }

  static SubMenu proxies({
    required Proxies? snapshot,
    required Mode mode,
    required void Function(String group, String node) onSelect,
    required void Function() onManage,
    bool unavailable = false,
  }) {
    final groups = (snapshot?.proxies.values ?? const <Object>[])
        .whereType<Group>()
        .where((group) => mode == Mode.Global || group.name != 'GLOBAL')
        .toList();
    // GLOBAL is the effective selector in global mode; show it first.
    if (mode == Mode.Global) {
      groups.sort((a, b) {
        if (a.name == b.name) return 0;
        if (a.name == 'GLOBAL') return -1;
        if (b.name == 'GLOBAL') return 1;
        return 0;
      });
    }
    return SubMenu(
      label: '代理',
      children: [
        if (mode == Mode.Direct)
          MenuItemLabel(label: '直连模式（DIRECT）', enabled: false)
        else if (unavailable)
          MenuItemLabel(label: '无法读取代理，请检查内核状态', enabled: false)
        else if (groups.isEmpty)
          MenuItemLabel(label: '暂无代理组，请先导入订阅', enabled: false)
        else
          for (final group in groups)
            SubMenu(
              label: '${group.name} → ${group.now}',
              children: [
                if (group.type != GroupType.Selector)
                  MenuItemLabel(label: '自动选择（${group.type.value}）', enabled: false),
                for (final node in group.all)
                  MenuItemCheckbox(
                    label: node,
                    checked: group.now == node,
                    enabled: group.type == GroupType.Selector,
                    onClicked: (_) => onSelect(group.name, node),
                  ),
              ],
            ),
        MenuSeparator(),
        MenuItemLabel(label: '管理代理…', onClicked: (_) => onManage()),
      ],
    );
  }
}
