import 'package:sensebox_bike/utils/json_validation.dart';

class Campaign {
  final String label;
  final String value;

  Campaign({required this.label, required this.value});

  factory Campaign.fromJson(Map<String, dynamic> json) {
    return Campaign(
      label: requireString(json, 'label', 'Campaign'),
      value: requireString(json, 'value', 'Campaign'),
    );
  }

  Map<String, String> toMap() {
    return {
      'label': label,
      'value': value,
    };
  }
}

