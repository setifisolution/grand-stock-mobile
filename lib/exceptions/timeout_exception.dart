class TimeoutException implements Exception {
  final String message;
  final String imageAsset;

  TimeoutException({
    required this.message,
    required this.imageAsset, // No default value → avoids const violation
  });

  @override
  String toString() => 'TimeoutException: $message';
}
