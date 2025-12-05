part of 'client.dart';

/// NATS client connection states
enum NatsConnectionState {
  /// Disconnected
  disconnected,

  /// Connecting
  connecting,

  /// Connected
  connected,

  /// Disconnecting
  disconnecting,
}

/// Base class for all NATS client events
sealed class NatsEvent {
  const NatsEvent({required this.timestamp});

  /// When the event occurred
  final DateTime timestamp;
}

/// Event emitted when connection is established
final class NatsConnectedEvent extends NatsEvent {
  const NatsConnectedEvent({
    required super.timestamp,
    required this.serverInfo,
    required this.uri,
  });

  /// Server information
  final ServerInfo serverInfo;

  /// The URI connected to
  final Uri uri;

  @override
  String toString() =>
      'NatsConnectedEvent(uri: $uri, server: ${serverInfo.serverId})';
}

/// Event emitted when connection is lost
final class NatsDisconnectedEvent extends NatsEvent {
  const NatsDisconnectedEvent({
    required super.timestamp,
    required this.uri,
    this.reason,
    this.willReconnect = false,
    this.reconnectAttempt = 0,
  });

  /// The URI that was disconnected
  final Uri uri;

  /// Reason for disconnection (if known)
  final String? reason;

  /// Whether the client will attempt to reconnect
  final bool willReconnect;

  /// Current reconnect attempt number (0 if not reconnecting)
  final int reconnectAttempt;

  @override
  String toString() =>
      'NatsDisconnectedEvent(uri: $uri, reason: $reason, '
      'willReconnect: $willReconnect, attempt: $reconnectAttempt)';
}

/// Event emitted when a connection error occurs
final class NatsErrorEvent extends NatsEvent {
  const NatsErrorEvent({
    required super.timestamp,
    required this.error,
    this.stackTrace,
    required this.uri,
    this.context,
  });

  /// The error that occurred
  final Object error;

  /// Stack trace if available
  final StackTrace? stackTrace;

  /// The URI where the error occurred
  final Uri uri;

  /// Additional context about when/where the error occurred
  final String? context;

  @override
  String toString() =>
      'NatsErrorEvent(uri: $uri, error: $error, '
      'context: $context)';
}

/// Event emitted when reconnection is being attempted
final class NatsReconnectingEvent extends NatsEvent {
  const NatsReconnectingEvent({
    required super.timestamp,
    required this.uri,
    required this.attempt,
    required this.maxAttempts,
    required this.delay,
  });

  /// The URI being reconnected to
  final Uri uri;

  /// Current attempt number
  final int attempt;

  /// Maximum attempts (-1 for unlimited)
  final int maxAttempts;

  /// Delay before this reconnection attempt
  final Duration delay;

  @override
  String toString() =>
      'NatsReconnectingEvent(uri: $uri, '
      'attempt: $attempt/$maxAttempts, delay: ${delay.inMilliseconds}ms)';
}

/// A NATS message
class NatsMessage {
  /// Creates a new message
  NatsMessage(this.subject, this.data, {this.replyTo, this.headers});

  /// The subject the message was published to
  final String subject;

  /// The message payload as bytes
  final Uint8List? data;

  /// The reply-to subject if this is a request
  final String? replyTo;

  /// Headers if this is a headers message
  final Map<String, String>? headers;

  /// The message payload as a string
  String? get string => data != null ? utf8.decode(data!) : null;
}

/// A subscription to a NATS subject
class NatsSubscription {
  /// Creates a new subscription
  NatsSubscription(this.subject, this.sid, this._client);

  /// The subject this subscription is for
  final String subject;

  /// The subscription ID
  final int sid;

  /// The client this subscription belongs to
  final NatsClient _client;

  final _controller = StreamController<NatsMessage>();

  /// Stream of messages received on this subscription
  Stream<NatsMessage> get stream => _controller.stream;

  /// Unsubscribe from this subscription
  Future<void> unsubscribe() async {
    _client.unSub(this);
    await _controller.close();
  }
}
