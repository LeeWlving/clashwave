// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'core_config.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$CoreConfig on CoreConfigBase, Store {
  Computed<bool>? _$tunEnableComputed;

  @override
  bool get tunEnable => (_$tunEnableComputed ??= Computed<bool>(
    () => super.tunEnable,
    name: 'CoreConfigBase.tunEnable',
  )).value;
  Computed<int>? _$mixedPortComputed;

  @override
  int get mixedPort => (_$mixedPortComputed ??= Computed<int>(
    () => super.mixedPort,
    name: 'CoreConfigBase.mixedPort',
  )).value;

  late final _$clashAtom = Atom(name: 'CoreConfigBase.clash', context: context);

  @override
  Config get clash {
    _$clashAtom.reportRead();
    return super.clash;
  }

  @override
  set clash(Config value) {
    _$clashAtom.reportWrite(value, super.clash, () {
      super.clash = value;
    });
  }

  late final _$setStateAsyncAction = AsyncAction(
    'CoreConfigBase.setState',
    context: context,
  );

  @override
  Future setState({
    int? redirPort,
    int? tproxyPort,
    int? mixedPort,
    bool? allowLan,
    Mode? mode,
    LogLevel? logLevel,
    bool? ipv6,
  }) {
    return _$setStateAsyncAction.run(
      () => super.setState(
        redirPort: redirPort,
        tproxyPort: tproxyPort,
        mixedPort: mixedPort,
        allowLan: allowLan,
        mode: mode,
        logLevel: logLevel,
        ipv6: ipv6,
      ),
    );
  }

  late final _$asyncConfigAsyncAction = AsyncAction(
    'CoreConfigBase.asyncConfig',
    context: context,
  );

  @override
  Future<void> asyncConfig() {
    return _$asyncConfigAsyncAction.run(() => super.asyncConfig());
  }

  @override
  String toString() {
    return '''
clash: ${clash},
tunEnable: ${tunEnable},
mixedPort: ${mixedPort}
    ''';
  }
}
