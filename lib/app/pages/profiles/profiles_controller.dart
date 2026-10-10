import 'package:asuka/asuka.dart';
import 'package:clash_for_flutter/app/bean/profile_base_bean.dart';
import 'package:clash_for_flutter/app/bean/profile_file_bean.dart';
import 'package:clash_for_flutter/app/bean/profile_url_bean.dart';
import 'package:clash_for_flutter/app/enum/type_enum.dart';
import 'package:clash_for_flutter/app/source/app_config.dart';
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
  final _config = Modular.get<AppConfig>();

  Future<void> addProfile(ProfileBase profile) => _config.importProfile(profile);

  /// 选择某源
  Future<void> select(String file) async {
    try {
      await _config.selectProfile(file);
    } catch (error) {
      Asuka.showSnackBar(SnackBar(content: Text('无法加载该订阅：$error')));
    }
  }

  Future<void> replaceFile(ProfileFile profile, String path) async {
    try {
      await _config.replaceFileProfile(profile, path);
    } catch (error) {
      Asuka.showSnackBar(SnackBar(content: Text('无法替换配置：$error')));
    }
  }

  /// 编辑源
  Future<void> edit(ProfileBase profile) async {
    try {
      await _config.editProfile(profile);
    } catch (error) {
      Asuka.showSnackBar(SnackBar(content: Text('无法修改配置：$error')));
    }
  }

  /// 移除源
  Future<void> removeProfile(String file) async {
    try {
      await _config.removeProfile(file);
    } catch (error) {
      Asuka.showSnackBar(SnackBar(content: Text('无法移除配置：$error')));
    }
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
