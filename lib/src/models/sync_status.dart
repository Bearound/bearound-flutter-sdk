class SyncStatus {
  final int secondsUntilNextSync;
  final bool isRanging;

  const SyncStatus({
    required this.secondsUntilNextSync,
    required this.isRanging,
  });

  factory SyncStatus.fromJson(Map<String, dynamic> json) {
    return SyncStatus(
      secondsUntilNextSync:
          (json['secondsUntilNextSync'] as num?)?.toInt() ?? 0,
      isRanging: json['isRanging'] as bool? ?? false,
    );
  }
}
