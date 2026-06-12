/// Config for the Android foreground-service notification shown while scanning
/// in background. Keeps the process alive on aggressive OEMs (Xiaomi/Huawei/
/// Samsung). **Android-only** — ignored on iOS.
class ForegroundScanConfig {
  final String? notificationTitle;
  final String? notificationText;
  final String? notificationChannelId;
  final String? notificationChannelName;

  const ForegroundScanConfig({
    this.notificationTitle,
    this.notificationText,
    this.notificationChannelId,
    this.notificationChannelName,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (notificationTitle != null) {
      map['notificationTitle'] = notificationTitle;
    }
    if (notificationText != null) {
      map['notificationText'] = notificationText;
    }
    if (notificationChannelId != null) {
      map['notificationChannelId'] = notificationChannelId;
    }
    if (notificationChannelName != null) {
      map['notificationChannelName'] = notificationChannelName;
    }
    return map;
  }
}

/// Contextual content for the Android foreground-service notification.
class NotificationContent {
  final String title;
  final String text;

  const NotificationContent({required this.title, required this.text});

  Map<String, dynamic> toJson() => {'title': title, 'text': text};
}
