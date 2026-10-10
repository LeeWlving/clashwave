import 'dart:async';

import 'package:clash_for_flutter/app/source/proxy_latency_tester.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tests shared nodes once and bounds concurrent core requests', () async {
    var active = 0;
    var maximum = 0;
    final measured = <String>[];
    final result = await const ProxyLatencyTester(concurrency: 2).test(
      ['HK', 'JP', 'US', 'HK', 'DE'],
      (name) async {
        measured.add(name);
        active++;
        if (active > maximum) maximum = active;
        await Future<void>.delayed(Duration.zero);
        active--;
        return 42;
      },
    );
    expect(maximum, 2);
    expect(measured, ['HK', 'JP', 'US', 'DE']);
    expect(result.keys, measured);
    expect(result.values, everyElement(42));
  });

  test('one timeout does not cancel other nodes', () async {
    final result = await const ProxyLatencyTester().test(['bad', 'good'], (name) async {
      if (name == 'bad') throw TimeoutException('core timeout');
      return 12;
    });
    expect(result, {'bad': null, 'good': 12});
  });

  test('switching a subscription stops scheduling tests of old nodes', () async {
    var cancelled = false;
    final measured = <String>[];
    final result = await const ProxyLatencyTester(concurrency: 1).test(['first', 'second'], (name) async {
      measured.add(name);
      cancelled = true;
      return 8;
    }, cancelled: () => cancelled);
    expect(measured, ['first']);
    expect(result, {'first': 8});
  });
}
