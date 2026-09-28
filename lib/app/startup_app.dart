import 'package:flutter/material.dart';
import 'package:clash_for_flutter/app/theme/clashwave_theme.dart';

/// Renders a window even when native core initialization fails.
class StartupApp extends StatefulWidget {
  const StartupApp({
    super.key,
    required this.initialize,
    required this.builder,
  });

  final Future<void> Function() initialize;
  final WidgetBuilder builder;

  @override
  State<StartupApp> createState() => _StartupAppState();
}

class _StartupAppState extends State<StartupApp> {
  late final Future<void> _initialization = Future.sync(widget.initialize);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return widget.builder(context);
        }
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ClashWaveTheme.light,
          darkTheme: ClashWaveTheme.dark,
          themeMode: ThemeMode.system,
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!snapshot.hasError) const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    Text(
                      snapshot.hasError ? 'ClashWave 启动失败' : '正在启动 ClashWave…',
                    ),
                    if (snapshot.hasError) ...[
                      const SizedBox(height: 16),
                      SelectableText(
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
