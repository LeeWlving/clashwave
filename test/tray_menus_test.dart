import 'package:clash_for_flutter/app/bean/group_bean.dart';
import 'package:clash_for_flutter/app/bean/history_bean.dart';
import 'package:clash_for_flutter/app/bean/profile_file_bean.dart';
import 'package:clash_for_flutter/app/bean/profile_url_bean.dart';
import 'package:clash_for_flutter/app/bean/proxies_bean.dart';
import 'package:clash_for_flutter/app/bean/proxy_bean.dart';
import 'package:clash_for_flutter/app/enum/type_enum.dart';
import 'package:clash_for_flutter/app/pages/index/tray_menus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_tray/system_tray.dart';

void main() {
  final first = ProfileURL.emptyBean()..file = 'first.yaml'..name = '订阅一';
  final second = ProfileURL.emptyBean()..file = 'second.yaml'..name = '订阅二';

  test('subscriptions select actual files and update only the active remote profile', () {
    String? selected;
    ProfileURL? updated;
    var managed = false;
    final menu = TrayMenus.subscriptions(
      profiles: [first, second], selectedFile: second.file,
      onSelect: (file) => selected = file, onUpdate: (profile) => updated = profile,
      onManage: () => managed = true,
    );
    final entries = menu.children.whereType<MenuItemCheckbox>().toList();
    expect(entries.map((item) => item.checked), [false, true]);
    entries.first.onClicked!(entries.first);
    expect(selected, first.file);
    final update = menu.children.firstWhere((item) => item.label == '更新当前订阅');
    update.onClicked!(update);
    expect(updated, same(second));
    menu.children.last.onClicked!(menu.children.last);
    expect(managed, isTrue);
    final local = TrayMenus.subscriptions(
      profiles: [ProfileFile.emptyBean()..file = 'local.yaml'], selectedFile: 'local.yaml',
      onSelect: (_) {}, onUpdate: (_) => fail('local files cannot be downloaded'), onManage: () {},
    );
    expect(local.children.any((item) => item.label == '更新当前订阅'), isFalse);
  });

  final selector = Group(name: '节点选择', type: GroupType.Selector,
    all: ['香港', '日本'], now: '日本');
  final automatic = Group(name: '自动选择', type: GroupType.URLTest,
    all: ['香港', '日本'], now: '香港');
  final balance = Group(name: '负载组', type: GroupType.LoadBalance,
    all: ['香港', '日本'], now: '香港');
  final global = Group(name: 'GLOBAL', type: GroupType.Selector,
    all: ['DIRECT', '自动选择', '节点选择', '负载组'], now: '节点选择');
  final snapshot = Proxies(proxies: {
    selector.name: selector, automatic.name: automatic, global.name: global, balance.name: balance,
    '香港': Proxy(name: '香港')..history = [History(time: 'old', delay: 20), History(time: 'new', delay: 90)],
    '日本': Proxy(name: '日本')..history = [History(time: 'new', delay: 30)],
  });

  List<MenuItemBase> groups(Mode mode, {void Function(String, String)? onSelect,
    void Function(Group)? onTest, bool sort = false, Map<String, int?> delays = const {}}) =>
      TrayMenus.proxyGroups(snapshot: snapshot, mode: mode,
        onSelect: onSelect ?? (_, _) {}, onTest: onTest ?? (_) {},
        sortByDelay: sort, delays: delays);

  test('root groups follow configuration order and automatic groups stay read-only', () {
    List<String>? choice;
    Group? tested;
    final menus = groups(Mode.Rule, onSelect: (group, node) => choice = [group, node],
      onTest: (group) => tested = group).whereType<SubMenu>().toList();
    expect(menus.map((group) => group.label), ['自动选择 → 香港', '节点选择 → 日本', '负载组 → 负载均衡']);
    expect(menus.first.children.whereType<MenuItemCheckbox>().every((node) => !node.enabled), isTrue);
    final nodes = menus[1].children.whereType<MenuItemCheckbox>().toList();
    expect(nodes.map((node) => node.checked), [false, true]);
    expect(nodes.map((node) => node.label), ['香港 · 90 ms', '日本 · 30 ms']);
    nodes.first.onClicked!(nodes.first);
    expect(choice, ['节点选择', '香港']);
    menus.first.children.first.onClicked!(menus.first.children.first);
    expect(tested, same(automatic));
    expect(menus.last.children.whereType<MenuItemCheckbox>().every((node) => !node.checked), isTrue);
  });

  test('global mode places GLOBAL first; direct mode still allows preselecting nodes', () {
    expect(groups(Mode.Global).first.label, startsWith('GLOBAL →'));
    expect(groups(Mode.Rule).any((item) => item.label.startsWith('GLOBAL →')), isFalse);
    expect(groups(Mode.Direct).whereType<SubMenu>(), hasLength(3));
  });

  test('sorting preserves callback node names and puts failures after live results', () {
    List<String>? choice;
    final selectorMenu = groups(Mode.Rule, sort: true, onSelect: (group, node) => choice = [group, node])
        .whereType<SubMenu>().elementAt(1);
    final nodes = selectorMenu.children.whereType<MenuItemCheckbox>().toList();
    expect(nodes.map((node) => node.label), ['日本 · 30 ms', '香港 · 90 ms']);
    nodes.first.onClicked!(nodes.first);
    expect(choice, ['节点选择', '日本']);
    final timeout = groups(Mode.Rule, sort: true, delays: {'日本': null, '香港': 0})
        .whereType<SubMenu>().elementAt(1).children.whereType<MenuItemCheckbox>();
    expect(timeout.map((node) => node.label), ['香港 · 超时', '日本 · 超时']);
    expect(TrayMenus.nodeLabel('尚未测试', snapshot, {}), '尚未测试 · 未测速');
  });

  test('unavailable core and empty profiles retain import and management actions', () {
    var imported = false;
    final menu = TrayMenus.subscriptions(profiles: [], selectedFile: null,
      onSelect: (_) {}, onUpdate: (_) {}, onManage: () {}, actions: [
        MenuItemLabel(label: '导入本地配置文件…', onClicked: (_) => imported = true),
      ]);
    expect(menu.children.first.enabled, isFalse);
    final item = menu.children.firstWhere((item) => item.label == '导入本地配置文件…');
    item.onClicked!(item);
    expect(imported, isTrue);
    final unavailable = TrayMenus.proxyGroups(snapshot: null, mode: Mode.Rule,
      unavailable: true, onSelect: (_, _) {}, onTest: (_) {});
    expect(unavailable.single.label, contains('无法读取代理'));
    expect(unavailable.single.enabled, isFalse);
  });
}
