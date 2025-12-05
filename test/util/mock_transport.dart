import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_nats/src/transport.dart';

/// Mock transport for testing
class MockTransport implements Transport {
  MockTransport();

  final _streamController = StreamController<Uint8List>.broadcast();
  final _outputController = StreamController<Uint8List>.broadcast();
  bool _isClosed = false;

  /// Stream of data sent by client (for verification)
  Stream<Uint8List> get outputStream => _outputController.stream;

  /// Whether the transport is closed
  bool get isClosed => _isClosed;

  @override
  Stream<Uint8List> get stream => _streamController.stream;

  @override
  void add(List<int> data) {
    if (!_isClosed) {
      _outputController.add(Uint8List.fromList(data));
    }
  }

  @override
  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;
    await _streamController.close();
    await _outputController.close();
  }

  /// Simulate server sending raw bytes
  void simulateServerData(Uint8List data) {
    if (!_isClosed) {
      _streamController.add(data);
    }
  }

  /// Simulate server sending a string (converted to bytes)
  void simulateServerString(String data) {
    simulateServerData(Uint8List.fromList(utf8.encode(data)));
  }

  /// Simulate server sending INFO packet
  void simulateInfo({
    String serverId = 'TEST_SERVER',
    String version = '2.10.0',
    int maxPayload = 1048576,
    bool headers = true,
  }) {
    final info = {
      'server_id': serverId,
      'server_name': 'test-server',
      'version': version,
      'proto': 1,
      'host': '127.0.0.1',
      'port': 4222,
      'headers': headers,
      'max_payload': maxPayload,
    };
    simulateServerString('INFO ${jsonEncode(info)}\r\n');
  }

  /// Simulate server sending +OK
  void simulateOk() {
    simulateServerString('+OK\r\n');
  }

  /// Simulate server sending -ERR
  void simulateError(String message) {
    simulateServerString("-ERR '$message'\r\n");
  }

  /// Simulate server sending PING
  void simulatePing() {
    simulateServerString('PING\r\n');
  }

  /// Simulate server sending PONG
  void simulatePong() {
    simulateServerString('PONG\r\n');
  }

  /// Simulate server sending MSG
  void simulateMsg({
    required String subject,
    required int sid,
    String? replyTo,
    required String payload,
  }) {
    final payloadBytes = utf8.encode(payload);
    if (replyTo != null) {
      simulateServerString(
        'MSG $subject $sid $replyTo ${payloadBytes.length}\r\n',
      );
    } else {
      simulateServerString('MSG $subject $sid ${payloadBytes.length}\r\n');
    }
    simulateServerData(Uint8List.fromList([...payloadBytes, 13, 10])); // \r\n
  }

  /// Simulate connection error/disconnect
  void simulateDisconnect() {
    if (!_isClosed) {
      _streamController.addError(
        const SocketException('Connection reset by peer'),
      );
    }
  }

  /// Reset the transport for reuse (simulating reconnection)
  void reset() {
    _isClosed = false;
  }
}

/// Factory function type for creating transports
typedef TransportFactory = Future<Transport> Function(Uri uri);

/// Creates a mock transport factory that returns the provided transports
/// in sequence for each connection attempt
TransportFactory createMockTransportFactory(List<MockTransport> transports) {
  var index = 0;
  return (Uri uri) async {
    if (index >= transports.length) {
      throw const SocketException('No more mock transports available');
    }
    return transports[index++];
  };
}

/// Creates a mock transport factory that always returns the same transport
TransportFactory createSingleMockTransportFactory(MockTransport transport) {
  return (Uri uri) async => transport;
}

/// Creates a mock transport factory that throws on connection
TransportFactory createFailingTransportFactory([String? message]) {
  return (Uri uri) async {
    throw SocketException(message ?? 'Connection refused');
  };
}
