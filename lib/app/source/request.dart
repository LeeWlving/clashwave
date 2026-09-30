import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clash_for_flutter/app/bean/config_bean.dart';
import 'package:clash_for_flutter/app/bean/clash_for_me_config_bean.dart';
import 'package:clash_for_flutter/app/bean/connection_bean.dart';
import 'package:clash_for_flutter/app/bean/group_bean.dart';
import 'package:clash_for_flutter/app/bean/log_bean.dart';
import 'package:clash_for_flutter/app/bean/net_speed.dart';
import 'package:clash_for_flutter/app/bean/profile_url_bean.dart';
import 'package:clash_for_flutter/app/bean/proxies_bean.dart';
import 'package:clash_for_flutter/app/bean/proxy_bean.dart';
import 'package:clash_for_flutter/app/bean/proxy_providers_bean.dart';
import 'package:clash_for_flutter/app/bean/sub_userinfo_bean.dart';
import 'package:clash_for_flutter/app/enum/type_enum.dart';
import 'package:clash_for_flutter/app/utils/constants.dart';
import 'package:clash_for_flutter/app/utils/app_json.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:clash_for_flutter/app/utils/proxy_port.dart';
import 'package:clash_for_flutter/app/utils/subscription_validation.dart';
import 'package:clash_for_flutter/core_control.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class Request {
  late final Dio _clashDio;

  final _dio = Dio(
    BaseOptions(
      // Subscription services use this header to choose the output format.
      // `clash.meta` requests a complete Mihomo-compatible YAML file.
      headers: {'User-Agent': DefaultConfigValue.subscriptionUserAgent},
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  Request() {
    _clashDio = Dio(
      BaseOptions(
        baseUrl: "http://${Constants.rustAddr}",
        headers: {'Authorization': 'Bearer ${Constants.controllerSecret}'},
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );
    // The local controller must never be sent through an environment proxy.
    _clashDio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => HttpClient()..findProxy = (_) => 'DIRECT',
    );
    _installReadableErrors(_clashDio, serviceName: 'Mihomo');
    _installReadableErrors(_dio, serviceName: '网络请求');
  }

  static void _installReadableErrors(Dio dio, {required String serviceName}) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          handler.reject(
            error.copyWith(message: _readableError(error, serviceName)),
          );
        },
      ),
    );
  }

  static String _readableError(DioException error, String serviceName) {
    final data = error.response?.data;
    String? detail;
    if (data is Map) {
      detail = data['message']?.toString() ?? data['error']?.toString();
    } else if (data is String && data.trim().isNotEmpty) {
      detail = data.trim();
    }

    if (detail != null && detail.isNotEmpty) {
      return '$serviceName：$detail';
    }

    final statusCode = error.response?.statusCode;
    if (statusCode != null) {
      return '$serviceName 请求失败（HTTP $statusCode）';
    }

    return switch (error.type) {
      DioExceptionType.connectionTimeout => '$serviceName 连接超时',
      DioExceptionType.sendTimeout => '$serviceName 发送超时',
      DioExceptionType.receiveTimeout => '$serviceName 响应超时',
      DioExceptionType.connectionError => '$serviceName 无法连接',
      DioExceptionType.cancel => '$serviceName 请求已取消',
      _ => '$serviceName 请求失败：${error.error ?? error.message}',
    };
  }

  static String _pathSegment(String value) => Uri.encodeComponent(value);

  void setSubscriptionUserAgent(String value) {
    _dio.options.headers['User-Agent'] = value;
  }

  Future<void> validateSubscriptionFile(String path) =>
      SubscriptionValidation.validateFile(File(path));

  Future<Response> downFile({
    required String urlPath,
    required String savePath,
    void Function(int, int)? onReceiveProgress,
    CancelToken? cancelToken,
  }) {
    return _dio.download(
      urlPath,
      savePath,
      onReceiveProgress: onReceiveProgress,
      cancelToken: cancelToken,
    );
  }

  /// 下载订阅
  Future<ProfileURL> getSubscribe({
    required ProfileURL profile,
    required String profilesDir,
  }) async {
    final time = DateTime.now();
    final file = "${time.microsecondsSinceEpoch}.yaml";
    final target = File("$profilesDir/$file");
    final partial = File('${target.path}.part');
    await target.parent.create(recursive: true);
    if (await partial.exists()) await partial.delete();

    try {
      final resp = await downFile(urlPath: profile.url, savePath: partial.path);
      await SubscriptionValidation.validateFile(partial);
      await partial.rename(target.path);
      String? filename;
      // 解析文件名
      if (profile.name.isEmpty) {
        var headerDis = resp.headers.value("content-disposition");
        if (headerDis != null) {
          var disposition = HeaderValue.parse(headerDis);
          disposition.parameters.forEach((key, value) {
            if (key.startsWith("filename")) {
              if (key == "filename*") {
                filename = Uri.decodeComponent((value ?? "").split("'").last);
              } else {
                filename = value;
              }
            }
          });
        }
        // 赋值文件名
        if (filename?.isNotEmpty ?? false) {
          profile.name = filename!;
        } else {
          profile.name = file;
        }
      }
      // 解析流量信息
      var headerInfo = resp.headers.value("subscription-userinfo");
      if (headerInfo != null) {
        profile.userinfo = SubUserinfo.formHString(headerInfo);
      }
      // 解析更新间隔
      var value = resp.headers.value("profile-update-interval");
      if (value != null && profile.interval == 0) {
        profile.interval = int.parse(value);
      }
      return profile
        ..time = time
        ..file = file;
    } catch (_) {
      if (await partial.exists()) await partial.delete();
      if (await target.exists()) await target.delete();
      rethrow;
    }
  }

  Future<Response> hello() async {
    if (Platform.isAndroid) {
      final initialized = await CoreControl.invokeAction('getIsInit');
      if (initialized != true) {
        throw StateError('Mihomo is not initialized');
      }
      return Response(
        requestOptions: RequestOptions(path: '/version'),
        statusCode: HttpStatus.ok,
      );
    }
    // `/version` is part of Mihomo's stable controller API. The root path is
    // not a portable health check and newer cores may reject it with HTTP 400.
    return _clashDio.get("/version");
  }

  /// 获取所有代理
  Future<Proxies?> getProxies() async {
    if (Platform.isAndroid) {
      final data = await CoreControl.invokeAction('getProxies');
      return data is String ? AppJson.fromJson<Proxies>(data) : null;
    }
    var res = await _clashDio.get<Map<String, dynamic>>("/proxies");
    return AppJson.fromMap<Proxies>(res.data);
  }

  /// 获取单个代理
  Future<dynamic> oneProxies(String name) async {
    var res = await _clashDio.get<Map<String, dynamic>>(
      "/proxies/${_pathSegment(name)}",
    );
    var data = res.data?.containsKey("now");
    return data == true
        ? AppJson.fromMap<Group>(res.data)
        : AppJson.fromMap<Proxy>(res.data);
  }

  /// 获取单个代理的延迟
  Future<int?> getProxyDelay(String name, String url) {
    if (Platform.isAndroid) {
      return CoreControl.invokeAction(
        'testDelay',
        jsonEncode({'proxy-name': name, 'test-url': url, 'timeout': 2900}),
      ).then((value) => value is int && value >= 0 ? value : null);
    }
    return _clashDio
        .get<Map>(
          "/proxies/${_pathSegment(name)}/delay",
          queryParameters: {"timeout": 2900, "url": url},
        )
        .then((res) => res.data?["delay"]);
  }

  /// 切换 Selector 中选中的代理
  Future<bool> changeProxy({
    required String name,
    required String select,
  }) async {
    if (Platform.isAndroid) {
      await CoreControl.invokeAction(
        'changeProxy',
        jsonEncode({'group-name': name, 'proxy-name': select}),
      );
      return true;
    }
    var resp = await _clashDio.put<void>(
      "/proxies/${_pathSegment(name)}",
      data: {"name": select},
    );
    return resp.statusCode == HttpStatus.noContent;
  }

  /// 获得当前的基础设置
  Future<Config?> getConfigs() async {
    if (Platform.isAndroid) {
      final data = await CoreControl.invokeAction(
        'getConfig',
        '${Constants.homeDir.path}${Constants.clashConfig}',
      );
      return data is Map
          ? AppJson.fromMap<Config>(Map<String, dynamic>.from(data))
          : null;
    }
    var res = await _clashDio.get<Map<String, dynamic>>("/configs");
    return AppJson.fromMap<Config>(res.data);
  }

  /// 切换配置文件 [path] 必须为绝对路径
  Future<bool> changeConfig(String path) async {
    // Subscription files often omit listeners; keep the application's port.
    final current = await getConfigs();
    final preferred = _validMixedPort(current?.mixedPort);
    final port = current?.mixedPort == preferred
        ? preferred
        : await ProxyPort.available(preferred);
    final payload = Config.prepareProfile(
      await File(path).readAsString(),
      mixedPort: port,
      geoxUrls: ClashForMeConfig.formFile().geoxUrls,
    );
    var resp = await _clashDio.put(
      "/configs",
      queryParameters: {"force": false},
      data: {"payload": payload},
    );
    if (resp.statusCode != HttpStatus.noContent) return false;
    if (!await patchConfigs(Config(mixedPort: port))) return false;
    await Config(mixedPort: port).saveFile();
    return true;
  }

  static int _validMixedPort(int? port) =>
      port != null && port > 0 && port <= 65535 ? port : 7890;

  /// Read live state rather than trusting a stale UI snapshot after a reload.
  Future<int> ensureMixedPort() async {
    final current = await getConfigs();
    if (current == null) throw StateError('无法读取内核代理端口');
    final preferred = _validMixedPort(current.mixedPort);
    final port = current.mixedPort == preferred
        ? preferred
        : await ProxyPort.available(preferred);
    if (current.mixedPort != port) {
      if (!await patchConfigs(Config(mixedPort: port))) {
        throw StateError('无法设置内核代理端口 $port');
      }
      final updated = await getConfigs();
      if (updated?.mixedPort != port) {
        throw StateError('内核代理端口 $port 未生效');
      }
    }
    await Config(mixedPort: port).saveFile();
    return port;
  }

  /// 增量修改配置
  Future<bool> patchConfigs(Config config) async {
    if (Platform.isAndroid) {
      await CoreControl.invokeAction(
        'updateConfig',
        jsonEncode(AppJson.toMap(config)),
      );
      return true;
    }
    var resp = await _clashDio.patch<void>(
      "/configs",
      data: AppJson.toMap(config),
    );
    return resp.statusCode == HttpStatus.noContent;
  }

  Future<ProxyProviders?> getProxyProviders() async {
    var res = await _clashDio.get<Map<String, dynamic>>("/providers/proxies");
    return AppJson.fromMap<ProxyProviders>(res.data);
  }

  /// 获取内核版本
  Future<String?> getClashVersion() async {
    if (Platform.isAndroid) return 'Mihomo 1.19.31';
    var res = await _clashDio.get<Map<String, dynamic>>("/version");
    return res.data?["version"];
  }

  Stream<NetSpeed?> traffic() {
    if (Platform.isAndroid) {
      return Stream.periodic(const Duration(seconds: 1)).asyncMap((_) async {
        final data = await CoreControl.invokeAction('getTraffic');
        return data is String ? AppJson.fromJson<NetSpeed>(data) : null;
      });
    }
    var channel = WebSocketChannel.connect(_authenticatedWebSocket('/traffic'));
    return channel.stream.map((event) => AppJson.fromJson<NetSpeed>(event));
  }

  Stream<LogData?> logs(LogLevel? level) {
    if (Platform.isAndroid) {
      // Android log events come from libmihomo's native event sink. Until a
      // listener is attached, keep startup independent from the REST socket.
      return const Stream<LogData?>.empty();
    }
    var uri = _authenticatedWebSocket('/logs', {'level': level?.value ?? ''});
    var channel = WebSocketChannel.connect(uri);
    return channel.stream.map(
      (event) => AppJson.fromJson<LogData>(event)?..time = DateTime.now(),
    );
  }

  Stream<Snapshot?> connections() {
    if (Platform.isAndroid) {
      return Stream.periodic(const Duration(seconds: 1)).asyncMap((_) async {
        final data = await CoreControl.invokeAction('getConnections');
        return data is String ? AppJson.fromJson<Snapshot>(data) : null;
      });
    }
    var channel = WebSocketChannel.connect(
      _authenticatedWebSocket('/connections'),
    );
    return channel.stream.map((event) => AppJson.fromJson<Snapshot>(event));
  }

  Uri _authenticatedWebSocket(
    String path, [
    Map<String, String> query = const {},
  ]) => Uri(
    scheme: 'ws',
    host: Constants.localhost,
    port: int.parse(Constants.rustAddr.split(':').last),
    path: path,
    queryParameters: {...query, 'token': Constants.controllerSecret},
  );

  Future<bool> closeAllConnections() async {
    if (Platform.isAndroid) {
      return await CoreControl.invokeAction('closeAllConnections') == true;
    }
    var resp = await _clashDio.delete<ResponseBody>("/connections");
    return resp.statusCode == HttpStatus.noContent;
  }

  Future<bool> closeConnections(String id) async {
    if (Platform.isAndroid) {
      return await CoreControl.invokeAction('closeConnection', id) == true;
    }
    var resp = await _clashDio.delete<ResponseBody>(
      "/connections/${_pathSegment(id)}",
    );
    return resp.statusCode == HttpStatus.noContent;
  }

  Future<String> latest() async {
    var resp = await _dio.get<Map<String, dynamic>>(Constants.releaseUrl);
    if (resp.data?.containsKey("tag_name") ?? false) {
      return resp.data!["tag_name"];
    } else {
      throw resp.data?["message"];
    }
  }
}
