/// Bound concurrency when a large subscription is tested from the menu bar.
/// Each name is tested once, even when it occurs in multiple proxy groups.
class ProxyLatencyTester {
  const ProxyLatencyTester({this.concurrency = 4}) : assert(concurrency > 0);
  final int concurrency;

  Future<Map<String, int?>> test(
    Iterable<String> names,
    Future<int?> Function(String name) measure, {
    bool Function()? cancelled,
    void Function(String name, int? delay)? onResult,
  }) async {
    final queue = names.toSet().toList();
    final results = <String, int?>{};
    var next = 0;
    Future<void> worker() async {
      while (next < queue.length && !(cancelled?.call() ?? false)) {
        final name = queue[next++];
        int? delay;
        try {
          delay = await measure(name);
        } catch (_) {
          delay = null;
        }
        results[name] = delay;
        onResult?.call(name, delay);
      }
    }
    await Future.wait(List.generate(concurrency, (_) => worker()));
    return results;
  }
}
