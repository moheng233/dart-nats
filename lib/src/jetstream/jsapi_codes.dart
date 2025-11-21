// Single place for JetStream error and status codes
// These constants are used throughout the library instead of magic numbers.

class JetStreamApiCodes {
  const JetStreamApiCodes._();

  static const int unknown = 0;
  static const int consumerNotFound = 10014;
  static const int streamNotFound = 10059;
  static const int streamAlreadyExists = 10058;
  static const int jetStreamNotEnabledForAccount = 10039;
  static const int streamWrongLastSequence = 10071;
  static const int noMessageFound = 10037;
}

class JetStreamStatusCodes {
  const JetStreamStatusCodes._();

  static const int none = 0;
  static const int idleHeartbeat = 100;
  static const int flowControlRequest = 100;
  static const int noResponders = 503;
  static const int requestTimeout = 408;
  static const int badRequest = 400;
  static const int consumerDeleted = 409;
  static const int streamDeleted = 409;
  static const int idleHeartbeatsMissed = 409;
  static const int exceededMaxWaiting = 409;
  static const int consumerIsPushBased = 409;
  static const int messageSizeExceedsMaxBytes = 409;
  static const int exceededMaxRequestBatch = 409;
  static const int exceededMaxExpires = 409;
  static const int messageNotFound = 404;
  static const int noResults = 404;
  static const int endOfBatch = 204;
}

/// Optional helper to map API error code to a string identifier.
String jetStreamApiCodeName(int? code) {
  switch (code) {
    case JetStreamApiCodes.consumerNotFound:
      return 'ConsumerNotFound';
    case JetStreamApiCodes.streamNotFound:
      return 'StreamNotFound';
    case JetStreamApiCodes.streamAlreadyExists:
      return 'StreamAlreadyExists';
    case JetStreamApiCodes.jetStreamNotEnabledForAccount:
      return 'JetStreamNotEnabledForAccount';
    case JetStreamApiCodes.streamWrongLastSequence:
      return 'StreamWrongLastSequence';
    case JetStreamApiCodes.noMessageFound:
      return 'NoMessageFound';
    default:
      return 'Unknown';
  }
}
