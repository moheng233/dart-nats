import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_nats/src/transformers/packet/s2c.dart';
import 'package:dart_nats/src/transformers/s2c.dart';
import 'package:test/test.dart';

void main() {
  group('NatsS2CTransformer', () {
    late NatsS2CTransformer transformer;

    setUp(() {
      transformer = NatsS2CTransformer();
    });

    /// Helper function to transform raw bytes to packets
    Future<List<NatsS2CPacket>> transform(String data) async {
      final bytes = Uint8List.fromList(utf8.encode(data));
      final stream = Stream.value(bytes).transform(transformer);
      return stream.toList();
    }

    group('INFO', () {
      test('should parse INFO packet with server information', () async {
        // Example from NATS protocol documentation
        const data =
            'INFO {"server_id":"Zk0GQ3JBSrg3oyxCRRlE09","version":"1.2.0",'
            '"proto":1,"go":"go1.10.3","host":"0.0.0.0","port":4222,'
            '"max_payload":1048576,"client_id":2392}\r\n';

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CInfoPacket>());

        final info = (packets[0] as NatsS2CInfoPacket).info;
        expect(info.serverId, equals('Zk0GQ3JBSrg3oyxCRRlE09'));
        expect(info.version, equals('1.2.0'));
        expect(info.proto, equals(1));
        expect(info.go, equals('go1.10.3'));
        expect(info.host, equals('0.0.0.0'));
        expect(info.port, equals(4222));
        expect(info.maxPayload, equals(1048576));
        expect(info.clientId, equals(2392));
      });

      test('should parse INFO packet with connect_urls', () async {
        const data = 'INFO {"server_id":"test","version":"2.0.0",'
            '"connect_urls":["10.0.0.184:4333","192.168.129.1:4333",'
            '"192.168.192.1:4333"]}\r\n';

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CInfoPacket>());

        final info = (packets[0] as NatsS2CInfoPacket).info;
        expect(info.serverId, equals('test'));
        expect(info.connectUrls, isNotNull);
        expect(info.connectUrls!.length, equals(3));
        expect(info.connectUrls, contains('10.0.0.184:4333'));
        expect(info.connectUrls, contains('192.168.129.1:4333'));
        expect(info.connectUrls, contains('192.168.192.1:4333'));
      });

      test('should parse INFO packet with TLS and auth options', () async {
        const data = 'INFO {"server_id":"secure_server","version":"2.0.0",'
            '"tls_required":true,"tls_verify":true,"auth_required":true,'
            '"nonce":"abcdef123456"}\r\n';

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CInfoPacket>());

        final info = (packets[0] as NatsS2CInfoPacket).info;
        expect(info.tlsRequired, isTrue);
        expect(info.tlsVerify, isTrue);
        expect(info.authRequired, isTrue);
        expect(info.nonce, equals('abcdef123456'));
      });

      test('should handle INFO packet case-insensitively', () async {
        const data = 'info {"server_id":"test","version":"1.0.0"}\r\n';

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CInfoPacket>());
      });
    });

    group('MSG', () {
      test('should parse MSG packet with payload', () async {
        // Example from NATS protocol documentation
        // MSG FOO.BAR 9 11\r\nHello World\r\n
        const data = 'MSG FOO.BAR 9 11\r\nHello World\r\n';

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CMsgPacket>());

        final msg = packets[0] as NatsS2CMsgPacket;
        expect(msg.subject, equals('FOO.BAR'));
        expect(msg.sid, equals(9));
        expect(msg.replyTo, isNull);
        expect(utf8.decode(msg.payload!), equals('Hello World'));
      });

      test('should parse MSG packet with reply-to subject', () async {
        // Example from NATS protocol documentation
        // MSG FOO.BAR 9 GREETING.34 11\r\nHello World\r\n
        const data = 'MSG FOO.BAR 9 GREETING.34 11\r\nHello World\r\n';

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CMsgPacket>());

        final msg = packets[0] as NatsS2CMsgPacket;
        expect(msg.subject, equals('FOO.BAR'));
        expect(msg.sid, equals(9));
        expect(msg.replyTo, equals('GREETING.34'));
        expect(utf8.decode(msg.payload!), equals('Hello World'));
      });

      test('should parse MSG packet with empty payload', () async {
        const data = 'MSG NOTIFY 5 0\r\n\r\n';

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CMsgPacket>());

        final msg = packets[0] as NatsS2CMsgPacket;
        expect(msg.subject, equals('NOTIFY'));
        expect(msg.sid, equals(5));
        expect(msg.payload, isNull);
      });

      test('should handle MSG packet case-insensitively', () async {
        const data = 'msg FOO 1 5\r\nHello\r\n';

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CMsgPacket>());

        final msg = packets[0] as NatsS2CMsgPacket;
        expect(msg.subject, equals('FOO'));
        expect(utf8.decode(msg.payload!), equals('Hello'));
      });
    });

    group('HMSG', () {
      test('should parse HMSG packet with headers', () async {
        // Example from NATS protocol documentation
        // HMSG FOO.BAR 34 45\r\nNATS/1.0\r\nFoodGroup: vegetable\r\n\r\n
        // Hello World\r\n
        const data = 'HMSG FOO.BAR 34 34 45\r\n'
            'NATS/1.0\r\n'
            'FoodGroup: vegetable\r\n'
            '\r\n'
            'Hello World\r\n';

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CHMsgPacket>());

        final msg = packets[0] as NatsS2CHMsgPacket;
        expect(msg.subject, equals('FOO.BAR'));
        expect(msg.sid, equals(34));
        expect(msg.replyTo, isNull);
        expect(utf8.decode(msg.payload!), equals('Hello World'));
        expect(msg.headers['FoodGroup'], equals('vegetable'));
      });

      test('should parse HMSG packet with reply-to and headers', () async {
        // Example from NATS protocol documentation
        // HMSG FOO.BAR 9 BAZ.69 34 45\r\nNATS/1.0\r\nFoodGroup: vegetable
        // \r\n\r\nHello World\r\n
        const data = 'HMSG FOO.BAR 9 BAZ.69 34 45\r\n'
            'NATS/1.0\r\n'
            'FoodGroup: vegetable\r\n'
            '\r\n'
            'Hello World\r\n';

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CHMsgPacket>());

        final msg = packets[0] as NatsS2CHMsgPacket;
        expect(msg.subject, equals('FOO.BAR'));
        expect(msg.sid, equals(9));
        expect(msg.replyTo, equals('BAZ.69'));
        expect(utf8.decode(msg.payload!), equals('Hello World'));
        expect(msg.headers['FoodGroup'], equals('vegetable'));
      });

      test('should parse HMSG packet with multiple headers', () async {
        const data = 'HMSG FRONT.DOOR 22 REPLY.1 45 56\r\n'
            'NATS/1.0\r\n'
            'BREAKFAST: donut\r\n'
            'LUNCH: burger\r\n'
            '\r\n'
            'Knock Knock\r\n';

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CHMsgPacket>());

        final msg = packets[0] as NatsS2CHMsgPacket;
        expect(msg.subject, equals('FRONT.DOOR'));
        expect(msg.sid, equals(22));
        expect(msg.replyTo, equals('REPLY.1'));
        expect(utf8.decode(msg.payload!), equals('Knock Knock'));
        expect(msg.headers['BREAKFAST'], equals('donut'));
        expect(msg.headers['LUNCH'], equals('burger'));
      });

      test('should parse HMSG packet with headers only (no payload)', () async {
        // HMSG with total bytes == header bytes means empty payload
        const data = 'HMSG NOTIFY 10 22 22\r\n'
            'NATS/1.0\r\n'
            'Bar: Baz\r\n'
            '\r\n'
            '\r\n';

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CHMsgPacket>());

        final msg = packets[0] as NatsS2CHMsgPacket;
        expect(msg.subject, equals('NOTIFY'));
        expect(msg.headers['Bar'], equals('Baz'));
      });

      test('should handle HMSG packet case-insensitively', () async {
        // NATS/1.0\r\n = 10 bytes
        // Key: Value\r\n = 12 bytes
        // \r\n = 2 bytes (empty line terminator)
        // Total header = 24 bytes
        // Hello NATS! = 11 bytes
        // Total = 35 bytes
        const data = 'hmsg FOO 1 24 35\r\n'
            'NATS/1.0\r\n'
            'Key: Value\r\n'
            '\r\n'
            'Hello NATS!\r\n';

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CHMsgPacket>());
      });
    });

    group('PING', () {
      test('should parse PING packet', () async {
        // Example from NATS protocol documentation
        const data = 'PING\r\n';

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CPingPacket>());
      });

      test('should handle PING packet case-insensitively', () async {
        const data = 'ping\r\n';

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CPingPacket>());
      });

      test('should handle mixed case PING', () async {
        const data = 'Ping\r\n';

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CPingPacket>());
      });
    });

    group('PONG', () {
      test('should parse PONG packet', () async {
        // Example from NATS protocol documentation
        const data = 'PONG\r\n';

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CPongPacket>());
      });

      test('should handle PONG packet case-insensitively', () async {
        const data = 'pong\r\n';

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CPongPacket>());
      });
    });

    group('+OK', () {
      test('should parse +OK packet', () async {
        // Example from NATS protocol documentation
        const data = '+OK\r\n';

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2COkPacket>());
      });

      test('should handle +OK packet case-insensitively', () async {
        const data = '+ok\r\n';

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2COkPacket>());
      });
    });

    group('-ERR', () {
      test("should parse -ERR 'Unknown Protocol Operation'", () async {
        const data = "-ERR 'Unknown Protocol Operation'\r\n";

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CErrPacket>());

        final err = packets[0] as NatsS2CErrPacket;
        expect(err.message, equals("'Unknown Protocol Operation'"));
      });

      test("should parse -ERR 'Authorization Violation'", () async {
        const data = "-ERR 'Authorization Violation'\r\n";

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CErrPacket>());

        final err = packets[0] as NatsS2CErrPacket;
        expect(err.message, equals("'Authorization Violation'"));
      });

      test("should parse -ERR 'Authorization Timeout'", () async {
        const data = "-ERR 'Authorization Timeout'\r\n";

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CErrPacket>());

        final err = packets[0] as NatsS2CErrPacket;
        expect(err.message, equals("'Authorization Timeout'"));
      });

      test("should parse -ERR 'Invalid Client Protocol'", () async {
        const data = "-ERR 'Invalid Client Protocol'\r\n";

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CErrPacket>());

        final err = packets[0] as NatsS2CErrPacket;
        expect(err.message, equals("'Invalid Client Protocol'"));
      });

      test("should parse -ERR 'Maximum Control Line Exceeded'", () async {
        const data = "-ERR 'Maximum Control Line Exceeded'\r\n";

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CErrPacket>());

        final err = packets[0] as NatsS2CErrPacket;
        expect(err.message, equals("'Maximum Control Line Exceeded'"));
      });

      test("should parse -ERR 'Parser Error'", () async {
        const data = "-ERR 'Parser Error'\r\n";

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CErrPacket>());

        final err = packets[0] as NatsS2CErrPacket;
        expect(err.message, equals("'Parser Error'"));
      });

      test("should parse -ERR 'Secure Connection - TLS Required'", () async {
        const data = "-ERR 'Secure Connection - TLS Required'\r\n";

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CErrPacket>());

        final err = packets[0] as NatsS2CErrPacket;
        expect(err.message, equals("'Secure Connection - TLS Required'"));
      });

      test("should parse -ERR 'Stale Connection'", () async {
        const data = "-ERR 'Stale Connection'\r\n";

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CErrPacket>());

        final err = packets[0] as NatsS2CErrPacket;
        expect(err.message, equals("'Stale Connection'"));
      });

      test("should parse -ERR 'Maximum Connections Exceeded'", () async {
        const data = "-ERR 'Maximum Connections Exceeded'\r\n";

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CErrPacket>());

        final err = packets[0] as NatsS2CErrPacket;
        expect(err.message, equals("'Maximum Connections Exceeded'"));
      });

      test("should parse -ERR 'Slow Consumer'", () async {
        const data = "-ERR 'Slow Consumer'\r\n";

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CErrPacket>());

        final err = packets[0] as NatsS2CErrPacket;
        expect(err.message, equals("'Slow Consumer'"));
      });

      test("should parse -ERR 'Maximum Payload Violation'", () async {
        const data = "-ERR 'Maximum Payload Violation'\r\n";

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CErrPacket>());

        final err = packets[0] as NatsS2CErrPacket;
        expect(err.message, equals("'Maximum Payload Violation'"));
      });

      test("should parse -ERR 'Invalid Subject'", () async {
        const data = "-ERR 'Invalid Subject'\r\n";

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CErrPacket>());

        final err = packets[0] as NatsS2CErrPacket;
        expect(err.message, equals("'Invalid Subject'"));
      });

      test('should parse -ERR with permissions violation', () async {
        const data =
            "-ERR 'Permissions Violation for Subscription to FOO.BAR'\r\n";

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CErrPacket>());

        final err = packets[0] as NatsS2CErrPacket;
        expect(
          err.message,
          equals("'Permissions Violation for Subscription to FOO.BAR'"),
        );
      });

      test('should parse -ERR with publish permissions violation', () async {
        const data =
            "-ERR 'Permissions Violation for Publish to SECRET.TOPIC'\r\n";

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CErrPacket>());

        final err = packets[0] as NatsS2CErrPacket;
        expect(
          err.message,
          equals("'Permissions Violation for Publish to SECRET.TOPIC'"),
        );
      });

      test('should handle -ERR packet case-insensitively', () async {
        const data = "-err 'Some Error'\r\n";

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CErrPacket>());

        final err = packets[0] as NatsS2CErrPacket;
        expect(err.message, equals("'Some Error'"));
      });
    });

    group('Multiple packets', () {
      test('should parse multiple packets in sequence', () async {
        const data = 'PING\r\n'
            'PONG\r\n'
            '+OK\r\n';

        final packets = await transform(data);

        expect(packets.length, equals(3));
        expect(packets[0], isA<NatsS2CPingPacket>());
        expect(packets[1], isA<NatsS2CPongPacket>());
        expect(packets[2], isA<NatsS2COkPacket>());
      });

      test('should parse INFO followed by PING', () async {
        // Typical server connection sequence
        const data = 'INFO {"server_id":"test","version":"1.0.0"}\r\n'
            'PING\r\n';

        final packets = await transform(data);

        expect(packets.length, equals(2));
        expect(packets[0], isA<NatsS2CInfoPacket>());
        expect(packets[1], isA<NatsS2CPingPacket>());
      });

      test('should parse multiple MSG packets', () async {
        const data = 'MSG FOO 1 5\r\nHello\r\n'
            'MSG BAR 2 5\r\nWorld\r\n';

        final packets = await transform(data);

        expect(packets.length, equals(2));
        expect(packets[0], isA<NatsS2CMsgPacket>());
        expect(packets[1], isA<NatsS2CMsgPacket>());

        final msg1 = packets[0] as NatsS2CMsgPacket;
        final msg2 = packets[1] as NatsS2CMsgPacket;

        expect(msg1.subject, equals('FOO'));
        expect(utf8.decode(msg1.payload!), equals('Hello'));
        expect(msg2.subject, equals('BAR'));
        expect(utf8.decode(msg2.payload!), equals('World'));
      });
    });

    group('Chunked data', () {
      test('should handle data split across chunks', () async {
        final chunk1 = Uint8List.fromList(utf8.encode('PIN'));
        final chunk2 = Uint8List.fromList(utf8.encode('G\r\n'));

        final stream = Stream.fromIterable([chunk1, chunk2]).transform(
          transformer,
        );
        final packets = await stream.toList();

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CPingPacket>());
      });

      test('should handle MSG payload split across chunks', () async {
        final chunk1 = Uint8List.fromList(utf8.encode('MSG FOO 1 11\r\nHello'));
        final chunk2 = Uint8List.fromList(utf8.encode(' World\r\n'));

        final stream = Stream.fromIterable([chunk1, chunk2]).transform(
          transformer,
        );
        final packets = await stream.toList();

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CMsgPacket>());

        final msg = packets[0] as NatsS2CMsgPacket;
        expect(utf8.decode(msg.payload!), equals('Hello World'));
      });

      test('should handle CRLF split across chunks', () async {
        final chunk1 = Uint8List.fromList(utf8.encode('PONG\r'));
        final chunk2 = Uint8List.fromList(utf8.encode('\n'));

        final stream = Stream.fromIterable([chunk1, chunk2]).transform(
          transformer,
        );
        final packets = await stream.toList();

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CPongPacket>());
      });
    });

    group('Edge cases', () {
      test('should handle empty stream', () async {
        final stream = Stream<Uint8List>.empty().transform(transformer);
        final packets = await stream.toList();

        expect(packets, isEmpty);
      });

      test('should handle empty chunk', () async {
        final chunk = Uint8List(0);
        final stream = Stream.value(chunk).transform(transformer);
        final packets = await stream.toList();

        expect(packets, isEmpty);
      });

      test('should handle whitespace delimiters (spaces)', () async {
        const data = 'MSG   FOO   1   5\r\nHello\r\n';

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CMsgPacket>());

        final msg = packets[0] as NatsS2CMsgPacket;
        expect(msg.subject, equals('FOO'));
      });

      test('should handle whitespace delimiters (tabs)', () async {
        const data = 'MSG\tFOO\t1\t5\r\nHello\r\n';

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CMsgPacket>());

        final msg = packets[0] as NatsS2CMsgPacket;
        expect(msg.subject, equals('FOO'));
      });

      test('should handle mixed whitespace delimiters', () async {
        const data = 'MSG \t FOO \t 1 \t 5\r\nHello\r\n';

        final packets = await transform(data);

        expect(packets.length, equals(1));
        expect(packets[0], isA<NatsS2CMsgPacket>());
      });
    });
  });
}
