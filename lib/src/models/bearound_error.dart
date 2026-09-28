class BearoundError {
  final String message;
  final String? details;

  /// Error domain, when the native side reports one: `BeAroundSDK` for errors the
  /// SDK raises itself (codes in [BearoundErrorCode]), or an Apple domain such as
  /// `kCLErrorDomain` for a CoreLocation failure forwarded as-is. Null on Android,
  /// which has no domain concept, and on older native SDKs.
  final String? domain;

  /// Numeric code paired with [domain]. Null when the native side sent none.
  ///
  /// [message] is a localized sentence in the device's language; never match on it.
  /// This is the stable field to switch on.
  final int? code;

  const BearoundError({
    required this.message,
    this.details,
    this.domain,
    this.code,
  });

  factory BearoundError.fromJson(Map<String, dynamic> json) {
    return BearoundError(
      message: json['message'] as String? ?? 'Unknown error',
      details: json['details'] as String?,
      domain: json['domain'] as String?,
      code: (json['code'] as num?)?.toInt(),
    );
  }

  /// True for the one error that is a permission state rather than a fault: iOS
  /// refused to arm beacon region monitoring because the app does not hold
  /// `Always` location authorization (`BeAroundSDK#11`, originally
  /// `kCLErrorDomain#4`).
  ///
  /// Detection keeps running on Bluetooth while the app is alive, but there is no
  /// wake-up for a backgrounded or terminated app. Treat it as a prompt to ask for
  /// `Always` (or to send the user to Settings), not as a crash to report.
  bool get isLocationAlwaysRequired =>
      (domain == 'BeAroundSDK' && code == 11) ||
      (domain == 'kCLErrorDomain' && code == 4);

  @override
  String toString() {
    final tag = domain == null ? '' : '[$domain#${code ?? '?'}] ';
    return 'BearoundError: $tag$message${details == null ? '' : ' ($details)'}';
  }
}
