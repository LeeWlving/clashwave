import 'package:clash_for_flutter/app/enum/type_enum.dart';

class Provider {
  String name;
  List<dynamic> proxies;
  String type;
  VehicleType vehicleType;
  String? updatedAt;

  Provider({
    required this.name,
    required this.proxies,
    required this.type,
    required this.vehicleType,
    this.updatedAt,
  });
}
