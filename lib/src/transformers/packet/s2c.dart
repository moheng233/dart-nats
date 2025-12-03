import 'dart:typed_data';

import '../../message.dart';
import '../types.dart';

final class NatsS2CErrPacket extends NatsS2CPacket {
  NatsS2CErrPacket(this.message);

  final String message;
}

final class NatsS2CHMsgPacket extends NatsS2CMsgPacket {
  NatsS2CHMsgPacket(
    super.subject,
    super.sid,
    super.payload, {
    required this.headers,
    super.replyTo,
  });

  final Map<String, String> headers;
}

final class NatsS2CInfoPacket extends NatsS2CPacket {
  NatsS2CInfoPacket(this.info);
  final ServerInfo info;
}

final class NatsS2CMsgPacket extends NatsS2CPacket {
  NatsS2CMsgPacket(this.subject, this.sid, this.payload, {this.replyTo});

  final String subject;
  final int sid;
  final String? replyTo;
  final Uint8List? payload;
}

final class NatsS2COkPacket extends NatsS2CPacket {
  NatsS2COkPacket();
}

sealed class NatsS2CPacket {}

final class NatsS2CPingPacket extends NatsS2CPacket {
  NatsS2CPingPacket();
}

final class NatsS2CPongPacket extends NatsS2CPacket {
  NatsS2CPongPacket();
}
