import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'common.dart';
import 'inbox.dart';
import 'transformers/c2s.dart';
import 'transformers/packet/c2s.dart';
import 'transformers/packet/s2c.dart';
import 'transformers/s2c.dart';
import 'transformers/types.dart';
import 'transport.dart';

part 'client_types.dart';
part 'client_extensions.dart';

/// Factory function type for creating transports
typedef TransportFactory = Future<Transport> Function(Uri uri);

/// Default transport factory that creates real transports
Future<Transport> _defaultTransportFactory(Uri uri) async {
  if (uri.scheme == 'ws' || uri.scheme == 'wss') {
    final channel = WebSocketChannel.connect(uri);
    await channel.ready;
    return WebSocketTransport(channel);
  } else if (uri.scheme == 'nats' || uri.scheme == 'tcp') {
    final socket = await Socket.connect(uri.host, uri.port);
    return SocketTransport(socket);
  } else {
    throw NatsException('Unsupported URI scheme: ${uri.scheme}');
  }
}

final class NatsClient {
  NatsClient(
    this.uri, {
    ConnectOptions? options,
    this.autoReconnect = true,
    this.reconnectDelay = const Duration(seconds: 2),
    this.maxReconnectAttempts = -1,
    TransportFactory? transportFactory,
    bool autoConnect = true,
  }) : _connectOptions = options ?? ConnectOptions(),
       _transportFactory = transportFactory ?? _defaultTransportFactory {
    if (autoConnect) {
      _scheduleConnect();
    }
  }

  final Uri uri;

  final ConnectOptions _connectOptions;
  final TransportFactory _transportFactory;

  /// Whether to automatically reconnect when disconnected
  final bool autoReconnect;

  /// Delay between reconnection attempts
  final Duration reconnectDelay;

  /// Maximum number of reconnection attempts (-1 for unlimited)
  final int maxReconnectAttempts;

  int _reconnectAttempts = 0;

  Timer? _reconnectTimer;
  Transport? _transport;

  StreamSubscription<NatsS2CPacket>? _packetSubscription;
  StreamSubscription<Uint8List>? _transportSubscription;
  StreamController<NatsC2SPacket>? _packetController;
  Completer<void>? _connectCompleter;
  NatsConnectionState _state = NatsConnectionState.disconnected;

  ServerInfo? _serverInfo;
  final _subscriptions = <int, NatsSubscription>{};

  int _nextSid = 1;
  // Inbox for request/response pattern
  final String _inboxPrefix = newInbox();

  int _inboxCounter = 0;
  NatsSubscription? _inboxSubscription;
  final _pendingRequests = <String, Completer<NatsMessage>>{};

  Timer? _pingTimer;
  Timer? _pongTimer;

  // Event stream for connection events
  final _eventController = StreamController<NatsEvent>.broadcast();

  /// Stream of client events (connected, disconnected, errors, etc.)
  Stream<NatsEvent> get events => _eventController.stream;

  String get inboxPrefix => _inboxPrefix;
  int get nextInboxId => _inboxCounter++;

  int get nextSid => _nextSid++;

  ServerInfo? get serverInfo => _serverInfo;

  NatsConnectionState get state => _state;

  Map<int, NatsSubscription> get subscriptions => _subscriptions;

  /// Close the connection
  Future<void> close() async {
    if (_state == NatsConnectionState.disconnected) return;

    _state = NatsConnectionState.disconnecting;
    _reconnectTimer?.cancel();

    // Close all subscription controllers
    for (final sub in _subscriptions.values) {
      await sub._controller.close();
    }
    _subscriptions.clear();
    _inboxSubscription = null;

    // Complete pending requests with error
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(NatsException('Connection closed'));
      }
    }
    _pendingRequests.clear();

    _cleanupConnection();

    // Emit disconnected event
    _emitEvent(
      NatsDisconnectedEvent(
        timestamp: DateTime.now(),
        uri: uri,
        reason: 'Client closed',
        willReconnect: false,
      ),
    );

    // Close event stream
    await _eventController.close();
  }

  /// Connect to a NATS server
  Future<void> connect() async {
    if (_state != NatsConnectionState.disconnected) {
      throw NatsException('Client is already connected or connecting');
    }

    _state = NatsConnectionState.connecting;
    _packetController = StreamController<NatsC2SPacket>();
    _connectCompleter = Completer<void>();

    // Create transport and set up transformers in a guarded zone
    // All errors in this zone are treated as connection failures
    unawaited(
      runZonedGuarded(
        () async {
          // Create transport using factory
          _transport = await _transportFactory(uri);

          // Set up transformers
          final rawStream = _transport!.stream;
          final packetStream = rawStream.transform(NatsS2CTransformer());
          final encodedStream = _packetController!.stream.transform(
            NatsC2STransformer(),
          );

          // Listen to encoded packets and send to transport
          _transportSubscription = encodedStream.listen((data) {
            _transport!.add(data);
          });

          // Listen to incoming packets
          _packetSubscription = packetStream.listen(
            _onPacket,
            onDone: _handleDisconnect,
          );

          // Send CONNECT packet
          _sendPacket(NatsC2SConnectPacket(_connectOptions));
        },
        (error, stack) {
          // Handle errors from the zone - connection failure
          if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
            _connectCompleter!.completeError(error);
          }
          _handleDisconnect(error: error, stackTrace: stack);
        },
      ),
    );

    // Wait for connection to complete (INFO or ERR packet)
    await _connectCompleter!.future;

    // Start ping timer if needed
    _startPingTimer();

    // Reset reconnect attempts on successful connection
    _reconnectAttempts = 0;
  }

  void _sendPacket(NatsC2SPacket packet) {
    _packetController?.add(packet);
  }

  /// Clean up connection resources
  void _cleanupConnection() {
    _pingTimer?.cancel();
    _pongTimer?.cancel();

    unawaited(_packetSubscription?.cancel());
    unawaited(_transportSubscription?.cancel());

    try {
      unawaited(_packetController?.close());
    } on Object catch (_) {
      // Ignore errors when closing controller
    }

    unawaited(_transport?.close());
    _transport = null;
    _packetController = null;
    _connectCompleter = null;
    _serverInfo = null;
    _state = NatsConnectionState.disconnected;
  }

  /// Handle disconnection and attempt to reconnect if enabled
  void _handleDisconnect({Object? error, StackTrace? stackTrace}) {
    if (_state == NatsConnectionState.disconnected ||
        _state == NatsConnectionState.disconnecting) {
      return;
    }

    final willReconnect =
        autoReconnect &&
        (maxReconnectAttempts == -1 ||
            _reconnectAttempts < maxReconnectAttempts);

    _cleanupConnection();

    // Emit error event if there was an error
    if (error != null) {
      _emitEvent(
        NatsErrorEvent(
          timestamp: DateTime.now(),
          error: error,
          stackTrace: stackTrace,
          uri: uri,
          context: 'Connection error',
        ),
      );
    }

    // Emit disconnected event
    _emitEvent(
      NatsDisconnectedEvent(
        timestamp: DateTime.now(),
        uri: uri,
        reason: error?.toString(),
        willReconnect: willReconnect,
        reconnectAttempt: _reconnectAttempts,
      ),
    );

    if (willReconnect) {
      _reconnectAttempts++;

      // Emit reconnecting event
      _emitEvent(
        NatsReconnectingEvent(
          timestamp: DateTime.now(),
          uri: uri,
          attempt: _reconnectAttempts,
          maxAttempts: maxReconnectAttempts,
          delay: reconnectDelay,
        ),
      );

      _scheduleConnect(delay: reconnectDelay);
    }
  }

  /// Emit an event to the event stream
  void _emitEvent(NatsEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  Future<void> _onPacket(NatsS2CPacket packet) async {
    switch (packet) {
      case NatsS2CErrPacket():
        final error = NatsException(packet.message);
        // Emit error event
        _emitEvent(
          NatsErrorEvent(
            timestamp: DateTime.now(),
            error: error,
            uri: uri,
            context: 'Server error: ${packet.message}',
          ),
        );
        if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
          _connectCompleter!.completeError(error);
        }
        throw error;
      case NatsS2CInfoPacket():
        _serverInfo = packet.info;
        _state = NatsConnectionState.connected;
        _resubscribeAll();
        if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
          _connectCompleter!.complete();
        }
        // Emit connected event
        _emitEvent(
          NatsConnectedEvent(
            timestamp: DateTime.now(),
            serverInfo: packet.info,
            uri: uri,
          ),
        );
      case NatsS2CHMsgPacket():
        final sub = _subscriptions[packet.sid];
        if (sub != null) {
          final msg = NatsMessage(
            packet.subject,
            packet.payload,
            replyTo: packet.replyTo,
            headers: packet.headers,
          );
          sub._controller.add(msg);
        }
      case NatsS2CMsgPacket():
        final sub = _subscriptions[packet.sid];
        if (sub != null) {
          final msg = NatsMessage(
            packet.subject,
            packet.payload,
            replyTo: packet.replyTo,
          );
          sub._controller.add(msg);
        }
      case NatsS2COkPacket():
      // Acknowledgment, no action needed
      case NatsS2CPingPacket():
        _sendPacket(NatsC2SPongPacket());
      case NatsS2CPongPacket():
        _pongTimer?.cancel();
    }
  }

  /// Resubscribe all subscriptions after reconnection
  void _resubscribeAll() {
    // Resubscribe existing subscriptions
    for (final sub in _subscriptions.values) {
      _sendPacket(NatsC2SSubPacket(sub.subject, sub.sid));
    }

    // Set up inbox subscription if not exists
    if (_inboxSubscription == null) {
      final inboxSubject = '$_inboxPrefix.>';
      final sid = _nextSid++;
      _inboxSubscription = NatsSubscription(inboxSubject, sid, this);
      _subscriptions[sid] = _inboxSubscription!;
      _sendPacket(NatsC2SSubPacket(inboxSubject, sid));

      // Listen for responses and dispatch to pending requests
      _inboxSubscription!.stream.listen((msg) {
        final requestId = msg.subject.substring(_inboxPrefix.length + 1);
        final completer = _pendingRequests.remove(requestId);
        if (completer != null && !completer.isCompleted) {
          completer.complete(msg);
        }
      });
    }
  }

  /// Schedule a connection attempt
  void _scheduleConnect({Duration delay = Duration.zero}) {
    _reconnectTimer?.cancel();
    if (delay == Duration.zero) {
      // Immediate connection via microtask
      scheduleMicrotask(() async {
        if (_state == NatsConnectionState.disconnected) {
          try {
            await connect();
          } on Object {
            // Connection failed, _handleDisconnect will handle retry
          }
        }
      });
    } else {
      // Delayed connection via timer
      _reconnectTimer = Timer(delay, () async {
        if (_state == NatsConnectionState.disconnected) {
          try {
            await connect();
          } on Object {
            // Connection failed, _handleDisconnect will handle retry
          }
        }
      });
    }
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    // Send ping every 2 minutes (NATS default)
    _pingTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (_state == NatsConnectionState.connected) {
        _sendPacket(NatsC2SPingPacket());
        _startPongTimer();
      }
    });
  }

  void _startPongTimer() {
    _pongTimer?.cancel();
    // Expect pong within 30 seconds
    _pongTimer = Timer(const Duration(seconds: 30), () {
      unawaited(close());
    });
  }

  /// Factory constructor that waits for connection to complete
  static Future<NatsClient> create(
    Uri uri, {
    ConnectOptions? options,
    bool autoReconnect = true,
    Duration reconnectDelay = const Duration(seconds: 2),
    int maxReconnectAttempts = -1,
    TransportFactory? transportFactory,
  }) async {
    final client = NatsClient(
      uri,
      options: options,
      autoReconnect: autoReconnect,
      reconnectDelay: reconnectDelay,
      maxReconnectAttempts: maxReconnectAttempts,
      transportFactory: transportFactory,
      autoConnect: false,
    );
    await client.connect();
    return client;
  }
}
