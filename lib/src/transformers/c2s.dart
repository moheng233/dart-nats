import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../message.dart';
import 'types.dart';

sealed class NatsC2SPacket {}

// 私有全局常量 - UTF-8 编码的协议字符串
const List<int> _connectPrefix = [67, 79, 78, 78, 69, 67, 84, 32]; // "CONNECT "
const List<int> _pubPrefix = [80, 85, 66, 32]; // "PUB "
const List<int> _hpubPrefix = [72, 80, 85, 66, 32]; // "HPUB "
const List<int> _subPrefix = [83, 85, 66, 32]; // "SUB "
const List<int> _unsubPrefix = [85, 78, 83, 85, 66, 32]; // "UNSUB "
const List<int> _crlf = [13, 10]; // "\r\n"
const List<int> _space = [32]; // " "

final Uint8List _ping = ascii.encode('PING\r\n'); // "PING\r\n"
final Uint8List _pong = ascii.encode('PONG\r\n'); // "PONG\r\n"

final class NatsC2SConnectPacket extends NatsC2SPacket {
  NatsC2SConnectPacket(this.options);
  
  final ConnectOptions options;
}

final class NatsC2SPubPacket extends NatsC2SPacket {
  NatsC2SPubPacket(this.subject, this.payload, {this.replyTo});
  
  final String subject;
  final String? replyTo;
  final Uint8List payload;
}

final class NatsC2SHPubPacket extends NatsC2SPacket {
  NatsC2SHPubPacket(this.subject, this.headers, this.payload, {this.replyTo});
  
  final String subject;
  final String? replyTo;
  final Header headers;
  final Uint8List payload;
}

final class NatsC2SSubPacket extends NatsC2SPacket {
  NatsC2SSubPacket(this.subject, this.sid, {this.queueGroup});
  
  final String subject;
  final String? queueGroup;
  final int sid;
}

final class NatsC2SUnsubPacket extends NatsC2SPacket {
  NatsC2SUnsubPacket(this.sid, {this.maxMsgs});
  
  final int sid;
  final int? maxMsgs;
}

final class NatsC2SPingPacket extends NatsC2SPacket {
  NatsC2SPingPacket();
}

final class NatsC2SPongPacket extends NatsC2SPacket {
  NatsC2SPongPacket();
}

final class NatsC2STransformer
    extends StreamTransformerBase<NatsC2SPacket, Uint8List> {

  @override
  Stream<Uint8List> bind(Stream<NatsC2SPacket> stream) async* {
    await for (final packet in stream) {
      final bytes = _encodePacket(packet);
      if (bytes.isNotEmpty) {
        yield bytes;
      }
    }
  }

  Uint8List _encodePacket(NatsC2SPacket packet) {
    if (packet is NatsC2SConnectPacket) {
      return _encodeConnect(packet);
    } else if (packet is NatsC2SPubPacket) {
      return _encodePub(packet);
    } else if (packet is NatsC2SHPubPacket) {
      return _encodeHPub(packet);
    } else if (packet is NatsC2SSubPacket) {
      return _encodeSub(packet);
    } else if (packet is NatsC2SUnsubPacket) {
      return _encodeUnsub(packet);
    } else if (packet is NatsC2SPingPacket) {
      return _encodePing();
    } else if (packet is NatsC2SPongPacket) {
      return _encodePong();
    }
    return Uint8List(0);
  }

  Uint8List _encodeConnect(NatsC2SConnectPacket packet) {
    final json = jsonEncode(packet.options.toJson());
    final result = BytesBuilder(copy: false)
      ..add(_connectPrefix)
      ..add(ascii.encode(json))
      ..add(_crlf);
    return result.takeBytes();
  }

  Uint8List _encodePub(NatsC2SPubPacket packet) {
    final result = BytesBuilder(copy: false)
      ..add(_pubPrefix)
      ..add(ascii.encode(packet.subject));
    
    if (packet.replyTo != null) {
      result
        ..add(_space)
        ..add(ascii.encode(packet.replyTo!));
    }
    
    result
      ..add(_space)
      ..add(ascii.encode(packet.payload.length.toString()))
      ..add(_crlf)
      ..add(packet.payload)
      ..add(_crlf);
    
    return result.takeBytes();
  }

  Uint8List _encodeHPub(NatsC2SHPubPacket packet) {
    final headerBytes = packet.headers.toBytes();
    final totalLength = headerBytes.length + packet.payload.length;
    
    final result = BytesBuilder(copy: false)
      ..add(_hpubPrefix)
      ..add(ascii.encode(packet.subject));
    
    if (packet.replyTo != null) {
      result
        ..add(_space)
        ..add(ascii.encode(packet.replyTo!));
    }
    
    result
      ..add(_space)
      ..add(ascii.encode(headerBytes.length.toString()))
      ..add(_space)
      ..add(ascii.encode(totalLength.toString()))
      ..add(_crlf)
      ..add(headerBytes)
      ..add(_crlf)
      ..add(packet.payload)
      ..add(_crlf);
    
    return result.takeBytes();
  }

  Uint8List _encodeSub(NatsC2SSubPacket packet) {
    final result = BytesBuilder(copy: false)
      ..add(_subPrefix)
      ..add(ascii.encode(packet.subject));
    
    if (packet.queueGroup != null) {
      result
        ..add(_space)
        ..add(ascii.encode(packet.queueGroup!));
    }
    
    result
      ..add(_space)
      ..add(ascii.encode(packet.sid.toString()))
      ..add(_crlf);
    
    return result.takeBytes();
  }

  Uint8List _encodeUnsub(NatsC2SUnsubPacket packet) {
    final result = BytesBuilder(copy: false)
      ..add(_unsubPrefix)
      ..add(ascii.encode(packet.sid.toString()));
    
    if (packet.maxMsgs != null) {
      result
        ..add(_space)
        ..add(ascii.encode(packet.maxMsgs!.toString()));
    }
    
    result.add(_crlf);
    
    return result.takeBytes();
  }

  Uint8List _encodePing() {
    return _ping;
  }

  Uint8List _encodePong() {
    return _pong;
  }
}
