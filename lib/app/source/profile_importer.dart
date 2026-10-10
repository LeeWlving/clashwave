import 'dart:io';

import 'package:clash_for_flutter/app/bean/profile_file_bean.dart';
import 'package:clash_for_flutter/app/utils/subscription_validation.dart';
import 'package:path/path.dart';

class ProfileImporter {
  static Future<ProfileFile> fromFile(String path, String profilesDir) async {
    final time = DateTime.now();
    final filename = '${time.microsecondsSinceEpoch}.yaml';
    final target = File('$profilesDir/$filename');
    final partial = File('${target.path}.part');
    await target.parent.create(recursive: true);
    try {
      await File(path).copy(partial.path);
      await SubscriptionValidation.validateFile(partial);
      await partial.rename(target.path);
      return ProfileFile(file: filename, name: basename(path), time: time, path: path);
    } catch (_) {
      if (await partial.exists()) await partial.delete();
      if (await target.exists()) await target.delete();
      rethrow;
    }
  }
}
