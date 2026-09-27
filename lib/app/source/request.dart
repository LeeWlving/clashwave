import 'dart:async';
import 'dart:io';

import 'package:clash_for_flutter/app/bean/config_bean.dart';
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
import 'package:web_socket_channel/web_socket_channel.dart';

class Request {
  final Dio _clashDio = Dio(
    BaseOptions(
      baseUrl: "http://${Constants.rustAddr}",
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );

  final _dio = Dio(
    BaseOptions(
      // Subscription services use this header to choose the output format.
      // `clash.meta` requests a complete Mihomo-compatible YAML file.
      headers: {'User-Agent': 'clash.meta'},
      connectTimeout: const Duration(seconds: 3),
    ),
  );

  Request() {
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

  Future<Response> downFile({
    required String urlPath,
    required String savePath,
    void Function(int, int)? onReceiveProgress,
  }) {
    return _dio.download(
      urlPath,
      savePath,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// 下载订阅
  Future<ProfileURL> getSubscribe({
    required ProfileURL profile,
    required String profilesDir,
  }) {
    var time = DateTime.now();
    var file = "${time.millisecondsSinceEpoch}.yaml";
    var savePath = "$profilesDir/$file";
    return downFile(urlPath: profile.url, savePath: savePath).then((resp) {
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
    });
  }

  Future<Response> hello() async {
    return _clashDio.get("/");
  }

  /// 获取所有代理
  Future<Proxies?> getProxies() async {
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
    var resp = await _clashDio.put<void>(
      "/proxies/${_pathSegment(name)}",
      data: {"name": select},
    );
    return resp.statusCode == HttpStatus.noContent;
  }

  /// 获得当前的基础设置
  Future<Config?> getConfigs() async {
    var res = await _clashDio.get<Map<String, dynamic>>("/configs");
    return AppJson.fromMap<Config>(res.data);
  }

  /// 切换配置文件 [path] 必须为绝对路径
  Future<bool> changeConfig(String path) async {
    var resp = await _clashDio.put(
      "/configs",
      queryParameters: {"force": false},
      data: {"path": path},
    );
    return resp.statusCode == HttpStatus.noContent;
  }

  /// 增量修改配置
  Future<bool> patchConfigs(Config config) async {
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
    var res = await _clashDio.get<Map<String, dynamic>>("/version");
    return res.data?["version"];
  }

  Stream<NetSpeed?> traffic() {
    var channel = WebSocketChannel.connect(
      Uri.parse("ws://${Constants.rustAddr}/traffic"),
    );
    return channel.stream.map((event) => AppJson.fromJson<NetSpeed>(event));
  }

  Stream<LogData?> logs(LogLevel? level) {
    var uri = Uri.parse(
      "ws://${Constants.rustAddr}/logs?level=${level?.value ?? ""}",
    );
    var channel = WebSocketChannel.connect(uri);
    return channel.stream.map(
      (event) => AppJson.fromJson<LogData>(event)?..time = DateTime.now(),
    );
  }

  Stream<Snapshot?> connections() {
    var channel = WebSocketChannel.connect(
      Uri.parse("ws://${Constants.rustAddr}/connections"),
    );
    return channel.stream.map((event) => AppJson.fromJson<Snapshot>(event));
  }

  Future<bool> closeAllConnections() async {
    var resp = await _clashDio.delete<ResponseBody>("/connections");
    return resp.statusCode == HttpStatus.noContent;
  }

  Future<bool> closeConnections(String id) async {
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
