import 'package:clash_for_flutter/app/bean/group_bean.dart';
import 'package:clash_for_flutter/app/bean/profile_url_bean.dart';
import 'package:clash_for_flutter/app/bean/proxies_bean.dart';
import 'package:clash_for_flutter/app/enum/type_enum.dart';
import 'package:clash_for_flutter/app/pages/index/tray_menus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_tray/system_tray.dart';

void main() {
  final first = ProfileURL.emptyBean()..file = 'first.yaml'..name = '订阅一';
  final second = ProfileURL.emptyBean()..file = 'second.yaml'..name = '订阅二';

  test('subscription menu selects the actual file and checks the active profile', () {
    String? selected;
    ProfileURL? updated;
    var managed = false;
    final menu = TrayMenus.subscriptions(
      profiles: [first, second], selectedFile: second.file,
      onSelect: (file) => selected = file,
      onUpdate: (profile) => updated = profile,
      onManage: () => managed = true,
    );
    final entries = menu.children.whereType<MenuItemCheckbox>().toList();
    expect(entries.map((item) => item.checked), [false, true]);
    entries.first.onClicked!(entries.first);
    expect(selected, first.file);
    final update = menu.children.firstWhere((item) => item.label == '更新当前订阅');
    update.onClicked!(update);
    expect(updated, same(second));
    final manage = menu.children.last;
    manage.onClicked!(manage);
    expect(managed, isTrue);
  });

  final selector = Group(name: '节点选择', type: GroupType.Selector,
    all: ['香港', '日本'], now: '日本');
  final automatic = Group(name: '自动选择', type: GroupType.URLTest,
    all: ['香港', '日本'], now: '香港');
  final global = Group(name: 'GLOBAL', type: GroupType.Selector,
    all: ['DIRECT', '节点选择'], now: '节点选择');
  final snapshot = Proxies(proxies: {
    selector.name: selector, automatic.name: automatic, global.name: global,
  });

  SubMenu proxyMenu(Mode mode, {void Function(String, String)? onSelect}) =>
    TrayMenus.proxies(snapshot: snapshot, mode: mode,
      onSelect: onSelect ?? (_, _) {}, onManage: () {});

  test('rule menu exposes groups and nodes, and keeps automatic groups read-only', () {
    List<String>? choice;
    final menu = proxyMenu(Mode.Rule, onSelect: (group, node) => choice = [group, node]);
    final groups = menu.children.whereType<SubMenu>().toList();
    expect(groups, hasLength(2));
    expect(groups.first.label, '节点选择 → 日本');
    final nodes = groups.first.children.whereType<MenuItemCheckbox>().toList();
    expect(nodes.map((node) => node.checked), [false, true]);
    nodes.first.onClicked!(nodes.first);
    expect(choice, ['节点选择', '香港']);
    expect(groups.last.children.whereType<MenuItemCheckbox>().every((item) => !item.enabled), isTrue);
    selector.now = '香港';
    final refreshed = proxyMenu(Mode.Rule).children.whereType<SubMenu>().first;
    expect(refreshed.children.whereType<MenuItemCheckbox>().map((node) => node.checked), [true, false]);
    selector.now = '日本';
  });

  test('global mode exposes GLOBAL first; direct mode has no selectable groups', () {
    expect(proxyMenu(Mode.Global).children.whereType<SubMenu>().first.label, startsWith('GLOBAL →'));
    expect(proxyMenu(Mode.Direct).children.whereType<SubMenu>(), isEmpty);
    expect(proxyMenu(Mode.Direct).children.first.enabled, isFalse);
  });

  test('empty profiles and failed core reads retain management entry points', () {
    final subscriptions = TrayMenus.subscriptions(profiles: [], selectedFile: null,
      onSelect: (_) {}, onUpdate: (_) {}, onManage: () {});
    expect(subscriptions.children.first.enabled, isFalse);
    expect(subscriptions.children.last.label, '管理订阅…');
    final proxies = TrayMenus.proxies(snapshot: null, mode: Mode.Rule,
      unavailable: true, onSelect: (_, _) {}, onManage: () {});
    expect(proxies.children.first.label, contains('无法读取代理'));
    expect(proxies.children.last.label, '管理代理…');
  });
}
