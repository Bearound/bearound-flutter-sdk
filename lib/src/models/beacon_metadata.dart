class BeaconMetadata {
  final String firmwareVersion;
  final int batteryLevel;
  final int movements;
  final int temperature;
  final int? txPower;
  final int? rssiFromBLE;
  final bool? isConnectable;

  const BeaconMetadata({
    required this.firmwareVersion,
    required this.batteryLevel,
    required this.movements,
    required this.temperature,
    this.txPower,
    this.rssiFromBLE,
    this.isConnectable,
  });

  factory BeaconMetadata.fromJson(Map<String, dynamic> json) {
    return BeaconMetadata(
      firmwareVersion: json['firmwareVersion'] as String? ?? '',
      batteryLevel: (json['batteryLevel'] as num?)?.toInt() ?? 0,
      movements: (json['movements'] as num?)?.toInt() ?? 0,
      temperature: (json['temperature'] as num?)?.toInt() ?? 0,
      txPower: (json['txPower'] as num?)?.toInt(),
      rssiFromBLE: (json['rssiFromBLE'] as num?)?.toInt(),
      isConnectable: json['isConnectable'] as bool?,
    );
  }
}
