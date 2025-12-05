import 'dart:typed_data';

import '../types.dart';

sealed class NatsC2SPacket {}

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
  final Map<String, String> headers;
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
