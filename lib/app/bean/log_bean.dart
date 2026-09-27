import 'package:clash_for_flutter/app/enum/type_enum.dart';

class LogData {
  DateTime? time;
  LogLevel type;
  String payload;

  LogData({this.time, required this.type, required this.payload});
}
