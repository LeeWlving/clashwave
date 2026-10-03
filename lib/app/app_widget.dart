import 'package:asuka/asuka.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:clash_for_flutter/app/theme/clashwave_theme.dart';
import 'package:clash_for_flutter/app/component/macos_window_frame.dart';

class AppWidget extends StatefulWidget {
  const AppWidget({super.key});

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

class _AppWidgetState extends State<AppWidget> {
  @override
  Widget build(BuildContext context) {
    var app = MaterialApp.router(
      title: "ClashWave",
      debugShowCheckedModeBanner: false,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [
        Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
          countryCode: "CN",
        ),
      ],
      locale: const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hans',
        countryCode: "CN",
      ),
      theme: ClashWaveTheme.light,
      darkTheme: ClashWaveTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: Modular.routerConfig,
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        final iconBrightness = brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: iconBrightness,
            statusBarBrightness: brightness,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: iconBrightness,
            systemNavigationBarDividerColor: Colors.transparent,
          ),
          child: MacosWindowFrame(child: Asuka.builder(context, child)),
        );
      },
      // navigatorObservers: [Asuka.asukaHeroController],
    );
    Modular.setObservers([Asuka.asukaHeroController]);
    return app;
  }
}
