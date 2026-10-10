import 'dart:io';

import 'package:asuka/asuka.dart';
import 'package:clash_for_flutter/app/bean/profile_base_bean.dart';
import 'package:clash_for_flutter/app/bean/profile_file_bean.dart';
import 'package:clash_for_flutter/app/bean/profile_url_bean.dart';
import 'package:clash_for_flutter/app/enum/type_enum.dart';
import 'package:clash_for_flutter/app/exceptions/message_exception.dart';
import 'package:clash_for_flutter/app/source/app_config.dart';
import 'package:clash_for_flutter/app/source/request.dart';
import 'package:clash_for_flutter/app/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class ProfileShow {
  final String title;
  final ProfileType type;
  int? use;
  int? total;
  DateTime? expire;
  final DateTime lastUpdate;

  ProfileShow({
    required this.title,
    required this.type,
    this.use,
    this.total,
    this.expire,
    required this.lastUpdate,
  });
}

class ProfileController {
  final _request = Modular.get<Request>();
  final _config = Modular.get<AppConfig>();

  Future<void> addProfile(ProfileBase profile) {
    Future<ProfileBase> handle;
    switch (profile.type) {
      case ProfileType.URL:
        final urlProfile = profile as ProfileURL;
        if (_config.hasSubscriptionUrl(urlProfile.url)) {
          return Future.error(MessageException('该订阅地址已经存在'));
        }
        handle = _request.getSubscribe(
          profile: urlProfile,
          profilesDir: _config.profilesPath,
        );
        break;
      case ProfileType.FILE:
        var time = DateTime.now();
        var file = "${time.microsecondsSinceEpoch}.yaml";
        var savePath = "${_config.profilesPath}/$file";
        var partialPath = '$savePath.part';
        handle = File((profile as ProfileFile).path!)
            .copy(partialPath)
            .then((_) => _request.validateSubscriptionFile(partialPath))
            .then((_) => File(partialPath).rename(savePath))
            .then((_) {
              return profile
                ..time = time
                ..file = file;
            })
            .catchError((error) async {
              final partial = File(partialPath);
              if (await partial.exists()) await partial.delete();
              final target = File(savePath);
              if (await target.exists()) await target.delete();
              throw error;
            });
        break;
    }

    return handle.then((p) async {
      if (_config.profiles.isEmpty) {
        try {
          if (!await _request.changeConfig('${_config.profilesPath}/${p.file}')) {
            throw MessageException('Mihomo 拒绝了该订阅');
          }
        } catch (_) {
          final file = File('${_config.profilesPath}/${p.file}');
          if (await file.exists()) await file.delete();
          rethrow;
        }
      }
      var tempList = _config.profiles.toList();
      tempList.add(p);
      _config.setState(profiles: tempList);
    });
  }

  /// 选择某源
  Future<void> select(String file) async {
    try {
      await _config.selectProfile(file);
    } catch (error) {
      Asuka.showSnackBar(SnackBar(content: Text('无法加载该订阅：$error')));
    }
  }

  /// 编辑源
  void edit(ProfileBase profile) {
    if (profile is ProfileURL &&
        _config.hasSubscriptionUrl(profile.url, exceptFile: profile.file)) {
      Asuka.showSnackBar(const SnackBar(content: Text('该订阅地址已经存在')));
      return;
    }
    var tempList = _config.profiles.toList();
    var i = tempList.indexWhere((element) => element.file == profile.file);
    tempList[i] = profile;
    _config.setState(profiles: tempList);
  }

  /// 移除源
  Future<void> removeProfile(String file) async {
    var isActive = _config.selectedFile == file;
    var tempList = _config.profiles.toList();
    tempList.removeWhere((e) => e.file == file);
    if (isActive && tempList.isNotEmpty) {
      try {
        await _config.selectProfile(tempList.first.file);
      } catch (error) {
        Asuka.showSnackBar(SnackBar(content: Text('无法移除当前订阅：$error')));
        return;
      }
    }
    _config.setState(profiles: tempList);
    final removed = File("${Constants.homeDir.path}${Constants.profilesPath}/$file");
    if (await removed.exists()) await removed.delete();
  }

  /// 更新源(仅限URL)
  Future<void> updateProfile(String file) async {
    final profile = _config.profiles.firstWhere((e) => e.file == file);
    if (profile is! ProfileURL) return;
    try {
      await _config.refreshProfile(profile);
    } catch (e) {
      Asuka.showSnackBar(SnackBar(content: Text("更新异常: $e")));
    }
  }
}
