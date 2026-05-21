class SenseBoxDevice {
  final String id;
  final String displayName;
  final String? advName;
  final bool isConnected;

  const SenseBoxDevice({
    required this.id,
    required this.displayName,
    this.advName,
    this.isConnected = false,
  });

  SenseBoxDevice copyWith({
    String? id,
    String? displayName,
    String? advName,
    bool? isConnected,
  }) {
    return SenseBoxDevice(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      advName: advName ?? this.advName,
      isConnected: isConnected ?? this.isConnected,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SenseBoxDevice &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
