import 'package:clash_for_flutter/app/source/desktop_presentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final events = <String>[];
  late DesktopPresentation presentation;
  setUp(() {
    events.clear();
    presentation = DesktopPresentation(
      lightMode: true,
      saveMode: (value) async => events.add('save:$value'),
      setSkipTaskbar: (value) async => events.add('dockHidden:$value'),
      show: () async => events.add('show'),
      hide: () async => events.add('hide'),
      focus: () async => events.add('focus'),
    );
  });
  tearDown(() => presentation.dashboardVisible.dispose());

  test('menu-bar startup does not open or create the dashboard', () {
    expect(presentation.dashboardVisible.value, isFalse);
    expect(events, isEmpty);
  });

  test('temporary dashboard use preserves startup preference and releases it on close', () async {
    final states = <bool>[];
    presentation.dashboardVisible.addListener(() => states.add(presentation.dashboardVisible.value));
    await presentation.openDashboard();
    expect(presentation.lightMode, isTrue);
    expect(events, ['show', 'focus']);
    await presentation.hideDashboard();
    expect(states, [true, false]);
    expect(events, ['show', 'focus', 'hide']);
    await presentation.openDashboard();
    expect(presentation.dashboardVisible.value, isTrue);
    expect(presentation.lightMode, isTrue);
    expect(events.where((event) => event.startsWith('save:')), isEmpty);
  });

  test('explicit preference changes are persisted and affect the Dock', () async {
    await presentation.setLightMode(false);
    expect(events, ['dockHidden:false', 'save:false', 'show', 'focus']);
    await presentation.hideDashboard();
    // Normal desktop mode retains its page tree when minimized/closed.
    expect(presentation.dashboardVisible.value, isTrue);
    await presentation.setLightMode(true);
    expect(events.sublist(events.length - 3), ['dockHidden:true', 'save:true', 'hide']);
    expect(presentation.dashboardVisible.value, isFalse);
  });

  test('failed preference persistence restores the native policy without hiding the GUI', () async {
    final calls = <String>[];
    final failing = DesktopPresentation(
      lightMode: false,
      saveMode: (_) async => throw StateError('disk full'),
      setSkipTaskbar: (value) async => calls.add('dockHidden:$value'),
      show: () async => calls.add('show'), hide: () async => calls.add('hide'),
      focus: () async => calls.add('focus'),
    );
    await expectLater(failing.setLightMode(true), throwsStateError);
    expect(failing.lightMode, isFalse);
    expect(failing.dashboardVisible.value, isTrue);
    expect(calls, ['dockHidden:true', 'dockHidden:false']);
    failing.dashboardVisible.dispose();
  });
}
