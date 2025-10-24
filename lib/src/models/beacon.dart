class Beacon {
  final String uuid;
  final int major;
  final int minor;
  final int rssi;
  final String? bluetoothName;
  final String? bluetoothAddress;
  final double? distanceMeters;
  final int? lastSeen;

  Beacon({
    required this.uuid,
    required this.major,
    required this.minor,
    required this.rssi,
    this.bluetoothName,
    this.bluetoothAddress,
    this.distanceMeters,
    this.lastSeen,
  });

  factory Beacon.fromJson(Map<String, dynamic> json) => Beacon(
    uuid: json['uuid'] as String,
    major: json['major'] as int,
    minor: json['minor'] as int,
    rssi: json['rssi'] as int,
    bluetoothName: json['bluetoothName'] as String?,
    bluetoothAddress: json['bluetoothAddress'] as String?,
    distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
    lastSeen: json['lastSeen'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'uuid': uuid,
    'major': major,
    'minor': minor,
    'rssi': rssi,
    'bluetoothName': bluetoothName,
    'bluetoothAddress': bluetoothAddress,
    'distanceMeters': distanceMeters,
    'lastSeen': lastSeen,
  };
}
