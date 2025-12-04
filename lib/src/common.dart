/// Nats Exception
class NatsException implements Exception {
  /// NatsException
  NatsException(this.message);

  /// Description of the cause of the timeout.
  final String? message;

  @override
  String toString() {
    var result = 'NatsException';
    if (message != null) result = '$result: $message';
    return result;
  }
}

/// nkeys Exception
class NkeysException implements Exception {
  /// NkeysException
  NkeysException(this.message);

  /// Description of the cause of the timeout.
  final String? message;

  @override
  String toString() {
    var result = 'NkeysException';
    if (message != null) result = '$result: $message';
    return result;
  }
}

/// Request Exception
class RequestError extends NatsException {
  /// RequestError
  RequestError(String super.message);
}
