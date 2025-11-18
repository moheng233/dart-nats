import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Abstract transport interface used by the NatsClient
abstract class Transport {
  /// Stream of incoming bytes from the transport
  Stream<Uint8List> get stream;

  /// Send bytes on the transport
  void add(List<int> data);

  /// Close the transport
  Future<void> close();
}

/// Socket based transport
class SocketTransport implements Transport {
  final Socket _socket;

  SocketTransport(this._socket);

  @override
  Stream<Uint8List> get stream => _socket.map((e) {
        return Uint8List.fromList(List<int>.from(e));
      });

  Socket get rawSocket => _socket;

  @override
  void add(List<int> data) => _socket.add(data);

  @override
  Future<void> close() async {
    await _socket.close();
  }
}

/// Secure socket based transport
class SecureSocketTransport implements Transport {
  final SecureSocket _socket;

  SecureSocketTransport(this._socket);

  @override
  Stream<Uint8List> get stream => _socket.map((e) {
        return Uint8List.fromList(List<int>.from(e));
      });

  SecureSocket get rawSocket => _socket;

  @override
  void add(List<int> data) => _socket.add(data);

  @override
  Future<void> close() async {
    await _socket.close();
  }
}

/// WebSocket based transport
class WebSocketTransport implements Transport {
  final WebSocketChannel _channel;

  WebSocketTransport(this._channel);

    @override
    Stream<Uint8List> get stream => _channel.stream.map((e) {
          if (e is Uint8List) return e;
          if (e is List<int>) return Uint8List.fromList(e);
          if (e is String) return Uint8List.fromList(utf8.encode(e));
          // Fallback: attempt to convert
          var list = (e as List).cast<int>();
          return Uint8List.fromList(list);
        });

  @override
  void add(List<int> data) => _channel.sink.add(data);

  @override
  Future<void> close() async {
    await _channel.sink.close();
  }
}
