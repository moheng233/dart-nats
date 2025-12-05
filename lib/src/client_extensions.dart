part of 'client.dart';

/// Extension methods for NatsClient providing pub/sub operations
extension NatsClientPubSubExtension on NatsClient {
  /// Publish a message to a subject
  void pub(
    String subject,
    Uint8List payload, {
    String? replyTo,
    Map<String, String>? headers,
  }) {
    if (headers != null) {
      _sendPacket(
        NatsC2SHPubPacket(subject, headers, payload, replyTo: replyTo),
      );
    } else {
      _sendPacket(NatsC2SPubPacket(subject, payload, replyTo: replyTo));
    }
  }

  /// Subscribe to a subject
  NatsSubscription sub(String subject, {String? queueGroup}) {
    final sid = nextSid;
    final subscription = NatsSubscription(subject, sid, this);
    subscriptions[sid] = subscription;
    _sendPacket(NatsC2SSubPacket(subject, sid, queueGroup: queueGroup));
    return subscription;
  }

  /// Unsubscribe from a subscription
  void unSub(NatsSubscription subscription, {int? maxMsgs}) {
    if (!subscriptions.containsKey(subscription.sid)) return;
    subscriptions.remove(subscription.sid);
    _sendPacket(NatsC2SUnsubPacket(subscription.sid, maxMsgs: maxMsgs));
  }

  /// Make a request and wait for a response
  Future<NatsMessage> request(
    String subject,
    Uint8List payload, {
    Duration? timeout,
  }) async {
    // Generate unique request id
    final requestId = nextInboxId.toString();
    final replyTo = '$inboxPrefix.$requestId';

    // Create completer and store in pending requests
    final completer = Completer<NatsMessage>();
    _pendingRequests[requestId] = completer;

    // Set up timeout if specified
    Timer? timer;
    if (timeout != null) {
      timer = Timer(timeout, () {
        if (_pendingRequests.remove(requestId) != null &&
            !completer.isCompleted) {
          completer.completeError(TimeoutException('Request timeout'));
        }
      });
    }

    // Send request
    pub(subject, payload, replyTo: replyTo);

    try {
      return await completer.future;
    } finally {
      timer?.cancel();
    }
  }
}

/// Extension methods for NatsClient providing string-based operations
extension NatsClientStringExtension on NatsClient {
  /// Publish a string message to a subject
  void pubString(
    String subject,
    String message, {
    String? replyTo,
    Map<String, String>? headers,
  }) {
    pub(
      subject,
      Uint8List.fromList(utf8.encode(message)),
      replyTo: replyTo,
      headers: headers,
    );
  }

  /// Make a string request and wait for a response
  Future<NatsMessage> requestString(
    String subject,
    String message, {
    Duration? timeout,
  }) async {
    return request(
      subject,
      Uint8List.fromList(utf8.encode(message)),
      timeout: timeout,
    );
  }
}
