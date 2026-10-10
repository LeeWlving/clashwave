import 'package:flutter/foundation.dart';

/// A dashboard can be opened temporarily without leaving menu-bar mode.
/// Hiding it in light mode releases the dashboard widget tree and its streams.
class DesktopPresentation {
  DesktopPresentation({
    required bool lightMode,
    required this.saveMode,
    required this.setSkipTaskbar,
    required this.show,
    required this.hide,
    required this.focus,
  }) : _lightMode = lightMode,
       dashboardVisible = ValueNotifier(!lightMode);

  bool _lightMode;
  bool get lightMode => _lightMode;
  final ValueNotifier<bool> dashboardVisible;
  final Future<void> Function(bool) saveMode;
  final Future<void> Function(bool) setSkipTaskbar;
  final Future<void> Function() show;
  final Future<void> Function() hide;
  final Future<void> Function() focus;

  Future<void> setLightMode(bool value) async {
    await setSkipTaskbar(value);
    try {
      await saveMode(value);
    } catch (_) {
      await setSkipTaskbar(_lightMode);
      rethrow;
    }
    _lightMode = value;
    if (value) {
      await hideDashboard();
    } else {
      await openDashboard();
    }
  }

  Future<void> openDashboard() async {
    dashboardVisible.value = true;
    await show();
    await focus();
  }

  Future<void> hideDashboard() async {
    await hide();
    if (_lightMode) dashboardVisible.value = false;
  }

  void windowFocused() => dashboardVisible.value = true;

  void windowHidden() {
    if (_lightMode) dashboardVisible.value = false;
  }
}
