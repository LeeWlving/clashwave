import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_tray/system_tray.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter/system_tray/menu_manager');

  test('refreshing a tray menu replaces its native instance and uses current callbacks', () async {
    final representations = <Map>[];
    var oldSelected = false;
    var newSelected = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      representations.add(call.arguments as Map);
      return true;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    final menu = Menu();
    await menu.buildFrom([MenuItemLabel(label: 'old', onClicked: (_) => oldSelected = true)]);
    final id = menu.menuId;
    await menu.buildFrom([MenuItemLabel(label: 'new', onClicked: (_) => newSelected = true)]);
    expect(menu.menuId, id);
    expect(representations.map((item) => item['menu_id']), [id, id]);
    final node = (representations.last['menu_list'] as List).single as Map;
    final call = channel.codec.encodeMethodCall(MethodCall('MenuItemSelectedCallback', {
      'menu_id': id, 'menu_item_id': node['id'],
    }));
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(channel.name, call, (_) {});
    expect(oldSelected, isFalse);
    expect(newSelected, isTrue);
  });
}
