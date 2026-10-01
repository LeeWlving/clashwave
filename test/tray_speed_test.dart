import 'package:clash_for_flutter/app/pages/index/tray_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'menu bar speed formatting uses bytes per second and binary thresholds',
    () {
      expect(TrayController.formatSpeed(0), '0 B/s');
      expect(TrayController.formatSpeed(1023), '1023 B/s');
      expect(TrayController.formatSpeed(1024), '1.0 KB/s');
      expect(TrayController.formatSpeed(1536), '1.5 KB/s');
      expect(TrayController.formatSpeed(1024 * 1024), '1.0 MB/s');
    },
  );
}
