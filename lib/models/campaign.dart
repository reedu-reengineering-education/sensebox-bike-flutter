class Campaign {
  final String label;
  final String value;

  Campaign({required this.label, required this.value});

  factory Campaign.fromJson(Map<String, dynamic> json) {
    return Campaign(
      label: json['label'] as String,
      value: json['value'] as String,
    );
  }

  Map<String, String> toMap() {
    return {
      'label': label,
      'value': value,
    };
  }
}

