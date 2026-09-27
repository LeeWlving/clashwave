import 'package:clash_for_flutter/app/enum/type_enum.dart';

/// 配置基本参数
abstract class ProfileBase {
  /// 保存的文件名
  String file;

  /// 名称
  String name;

  /// 配置类型
  ProfileType type;

  /// 更新的时间
  DateTime time;

  ProfileBase({
    required this.name,
    required this.file,
    required this.type,
    required this.time,
  });
}
