class BearoundError {
  final String message;
  final String? details;

  const BearoundError({required this.message, this.details});

  factory BearoundError.fromJson(Map<String, dynamic> json) {
    return BearoundError(
      message: json['message'] as String? ?? 'Unknown error',
      details: json['details'] as String?,
    );
  }
}
