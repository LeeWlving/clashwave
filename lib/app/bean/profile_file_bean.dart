import 'package:clash_for_flutter/app/bean/profile_base_bean.dart';
import 'package:clash_for_flutter/app/enum/type_enum.dart';

/// 配置(文件)
class ProfileFile extends ProfileBase {
  /// 链接地址
  String? path;

  ProfileFile({
    required super.file,
    required super.name,
    required super.time,
    this.path,
  }) : super(type: ProfileType.FILE);

  factory ProfileFile.defaultBean({
    required String file,
    required String name,
    required DateTime time,
  }) => ProfileFile(file: file, name: name, time: time);

  factory ProfileFile.emptyBean() =>
      ProfileFile(file: "", name: "", time: DateTime.now());
}
