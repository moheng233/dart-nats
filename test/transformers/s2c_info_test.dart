import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_nats/src/transformers/packet/s2c.dart';
import 'package:dart_nats/src/transformers/s2c.dart';
import 'package:dart_nats/src/transformers/types.dart';
import 'package:test/test.dart';

void main() {
  group('NatsS2CTransformer INFO Protocol Tests', () {
    late NatsS2CTransformer transformer;

    setUp(() {
      transformer = NatsS2CTransformer();
    });

    group('INFO Protocol Parsing', () {
      test('should parse basic INFO message', () async {
        final infoJson = {
          'server_id': 'test-server-123',
          'server_name': 'nats-server',
          'version': '2.9.0',
          'proto': 1,
          'go': 'go1.19.0',
          'host': 'localhost',
          'port': 4222,
          'max_payload': 1048576,
        };

        final infoMessage = 'INFO ${jsonEncode(infoJson)}\r\n';
        final stream = Stream.value(
          Uint8List.fromList(utf8.encode(infoMessage)),
        );
        final packets = await transformer.bind(stream).toList();

        expect(packets, hasLength(1));
        expect(packets[0], isA<NatsS2CInfoPacket>());

        final infoPacket = packets[0] as NatsS2CInfoPacket;
        final serverInfo = infoPacket.info;

        expect(serverInfo.serverId, equals('test-server-123'));
        expect(serverInfo.serverName, equals('nats-server'));
        expect(serverInfo.version, equals('2.9.0'));
        expect(serverInfo.proto, equals(1));
        expect(serverInfo.go, equals('go1.19.0'));
        expect(serverInfo.host, equals('localhost'));
        expect(serverInfo.port, equals(4222));
        expect(serverInfo.maxPayload, equals(1048576));
      });

      test('should parse INFO message with all fields', () async {
        final infoJson = {
          'server_id': 'server-456',
          'server_name': 'cluster-node-1',
          'version': '2.10.0',
          'proto': 1,
          'go': 'go1.20.0',
          'host': '192.168.1.100',
          'port': 4222,
          'headers': true,
          'max_payload': 1048576,
          'connect_urls': ['192.168.1.101:4222', '192.168.1.102:4222'],
          'tls_required': true,
          'tls_available': true,
          'tls_verify': false,
          'auth_required': true,
          'nonce': 'random-nonce-string',
          'client_id': 12345,
          'client_ip': '192.168.1.50',
          'cluster': 'test-cluster',
          'ldm': false,
        };

        final infoMessage = 'INFO ${jsonEncode(infoJson)}\r\n';
        final stream = Stream.value(
          Uint8List.fromList(utf8.encode(infoMessage)),
        );
        final packets = await transformer.bind(stream).toList();

        expect(packets, hasLength(1));
        final infoPacket = packets[0] as NatsS2CInfoPacket;
        final serverInfo = infoPacket.info;

        // Basic fields
        expect(serverInfo.serverId, equals('server-456'));
        expect(serverInfo.serverName, equals('cluster-node-1'));
        expect(serverInfo.version, equals('2.10.0'));
        expect(serverInfo.proto, equals(1));
        expect(serverInfo.go, equals('go1.20.0'));
        expect(serverInfo.host, equals('192.168.1.100'));
        expect(serverInfo.port, equals(4222));

        // Boolean fields
        expect(serverInfo.headers, isTrue);
        expect(serverInfo.tlsRequired, isTrue);
        expect(serverInfo.tlsAvailable, isTrue);
        expect(serverInfo.tlsVerify, isFalse);
        expect(serverInfo.authRequired, isTrue);
        expect(serverInfo.lameDuckMode, isFalse);

        // Numeric fields
        expect(serverInfo.maxPayload, equals(1048576));
        expect(serverInfo.clientId, equals(12345));

        // String fields
        expect(serverInfo.nonce, equals('random-nonce-string'));
        expect(serverInfo.clientIp, equals('192.168.1.50'));
        expect(serverInfo.cluster, equals('test-cluster'));

        // List fields
        expect(serverInfo.connectUrls, hasLength(2));
        expect(serverInfo.connectUrls, contains('192.168.1.101:4222'));
        expect(serverInfo.connectUrls, contains('192.168.1.102:4222'));
      });

      test('should parse INFO message with minimal fields', () async {
        final infoJson = {
          'server_id': 'minimal-server',
          'version': '2.8.0',
          'proto': 1,
          'host': 'localhost',
          'port': 4222,
        };

        final infoMessage = 'INFO ${jsonEncode(infoJson)}\r\n';
        final stream = Stream.value(
          Uint8List.fromList(utf8.encode(infoMessage)),
        );
        final packets = await transformer.bind(stream).toList();

        expect(packets, hasLength(1));
        final infoPacket = packets[0] as NatsS2CInfoPacket;
        final serverInfo = infoPacket.info;

        expect(serverInfo.serverId, equals('minimal-server'));
        expect(serverInfo.version, equals('2.8.0'));
        expect(serverInfo.proto, equals(1));
        expect(serverInfo.host, equals('localhost'));
        expect(serverInfo.port, equals(4222));

        // Optional fields should be null
        expect(serverInfo.serverName, isNull);
        expect(serverInfo.go, isNull);
        expect(serverInfo.headers, isNull);
        expect(serverInfo.maxPayload, isNull);
        expect(serverInfo.connectUrls, isNull);
        expect(serverInfo.tlsRequired, isNull);
        expect(serverInfo.tlsAvailable, isNull);
        expect(serverInfo.tlsVerify, isNull);
        expect(serverInfo.authRequired, isNull);
        expect(serverInfo.nonce, isNull);
        expect(serverInfo.clientId, isNull);
        expect(serverInfo.clientIp, isNull);
        expect(serverInfo.cluster, isNull);
        expect(serverInfo.lameDuckMode, isNull);
      });

      test('should parse INFO message with empty connect_urls', () async {
        final infoJson = {
          'server_id': 'server-with-empty-urls',
          'version': '2.9.0',
          'proto': 1,
          'host': 'localhost',
          'port': 4222,
          'connect_urls': <String>[],
        };

        final infoMessage = 'INFO ${jsonEncode(infoJson)}\r\n';
        final stream = Stream.value(
          Uint8List.fromList(utf8.encode(infoMessage)),
        );
        final packets = await transformer.bind(stream).toList();

        expect(packets, hasLength(1));
        final infoPacket = packets[0] as NatsS2CInfoPacket;
        final serverInfo = infoPacket.info;

        expect(serverInfo.connectUrls, isNotNull);
        expect(serverInfo.connectUrls, isEmpty);
      });

      test(
        'should parse INFO message with connect_urls field missing',
        () async {
          final infoJson = {
            'server_id': 'server-without-urls',
            'version': '2.9.0',
            'proto': 1,
            'host': 'localhost',
            'port': 4222,
          };

          final infoMessage = 'INFO ${jsonEncode(infoJson)}\r\n';
          final stream = Stream.value(
            Uint8List.fromList(utf8.encode(infoMessage)),
          );
          final packets = await transformer.bind(stream).toList();

          expect(packets, hasLength(1));
          final infoPacket = packets[0] as NatsS2CInfoPacket;
          final serverInfo = infoPacket.info;

          expect(serverInfo.connectUrls, isNull);
        },
      );

      test('should handle case insensitive INFO command', () async {
        final infoJson = {
          'server_id': 'case-test-server',
          'version': '2.9.0',
          'proto': 1,
        };

        // Test different case variations
        final variations = [
          'INFO ${jsonEncode(infoJson)}\r\n',
          'info ${jsonEncode(infoJson)}\r\n',
          'InFo ${jsonEncode(infoJson)}\r\n',
          'iNfO ${jsonEncode(infoJson)}\r\n',
        ];

        for (final variation in variations) {
          final stream = Stream.value(
            Uint8List.fromList(utf8.encode(variation)),
          );
          final packets = await transformer.bind(stream).toList();

          expect(packets, hasLength(1));
          expect(packets[0], isA<NatsS2CInfoPacket>());

          final infoPacket = packets[0] as NatsS2CInfoPacket;
          expect(infoPacket.info.serverId, equals('case-test-server'));
        }
      });

      test('should handle whitespace variations in INFO message', () async {
        final infoJson = {
          'server_id': 'whitespace-test',
          'version': '2.9.0',
          'proto': 1,
        };

        final variations = [
          'INFO   ${jsonEncode(infoJson)}\r\n', // Multiple spaces
          'INFO\t${jsonEncode(infoJson)}\r\n', // Tab
          'INFO \t ${jsonEncode(infoJson)}\r\n', // Mixed whitespace
          'INFO ${jsonEncode(infoJson)} \r\n', // Trailing space
        ];

        for (final variation in variations) {
          final stream = Stream.value(
            Uint8List.fromList(utf8.encode(variation)),
          );
          final packets = await transformer.bind(stream).toList();

          expect(packets, hasLength(1));
          expect(packets[0], isA<NatsS2CInfoPacket>());
        }
      });

      test('should parse INFO message with large numbers', () async {
        final infoJson = {
          'server_id': 'large-numbers-server',
          'version': '2.9.0',
          'proto': 1,
          'max_payload': 1073741824, // 1GB
          'client_id': 9223372036854775807, // Max int64
        };

        final infoMessage = 'INFO ${jsonEncode(infoJson)}\r\n';
        final stream = Stream.value(
          Uint8List.fromList(utf8.encode(infoMessage)),
        );
        final packets = await transformer.bind(stream).toList();

        expect(packets, hasLength(1));
        final infoPacket = packets[0] as NatsS2CInfoPacket;
        final serverInfo = infoPacket.info;

        expect(serverInfo.maxPayload, equals(1073741824));
        expect(serverInfo.clientId, equals(9223372036854775807));
      });

      test('should parse INFO message with unicode characters', () async {
        final infoJson = {
          'server_id': 'unicode-测试-сервер',
          'server_name': 'NATS服务器-тест',
          'version': '2.9.0',
          'proto': 1,
        };

        final infoMessage = 'INFO ${jsonEncode(infoJson)}\r\n';
        final stream = Stream.value(
          Uint8List.fromList(utf8.encode(infoMessage)),
        );
        final packets = await transformer.bind(stream).toList();

        expect(packets, hasLength(1));
        final infoPacket = packets[0] as NatsS2CInfoPacket;
        final serverInfo = infoPacket.info;

        expect(serverInfo.serverId, equals('unicode-测试-сервер'));
        expect(serverInfo.serverName, equals('NATS服务器-тест'));
      });
    });

    group('INFO Protocol Error Handling', () {
      test('should handle malformed JSON in INFO message', () async {
        const malformedJson = '{"server_id": "test", "version": "2.9.0",}';
        const infoMessage = 'INFO $malformedJson\r\n';
        final stream = Stream.value(
          Uint8List.fromList(utf8.encode(infoMessage)),
        );

        // Should not throw exception, but should not produce INFO packet
        final packets = await transformer.bind(stream).toList();

        // Should be empty or contain error packets, not crash
        expect(packets, isEmpty);
      });

      test('should handle non-object JSON in INFO message', () async {
        const nonObjectJson = '["not", "an", "object"]';
        const infoMessage = 'INFO $nonObjectJson\r\n';
        final stream = Stream.value(
          Uint8List.fromList(utf8.encode(infoMessage)),
        );

        final packets = await transformer.bind(stream).toList();

        // Should be empty since JSON is not a Map
        expect(packets, isEmpty);
      });

      test('should ignore non-INFO protocol messages', () async {
        final messages = [
          'PING\r\n',
          'PONG\r\n',
          '+OK\r\n',
          '-ERR some error\r\n',
          'MSG test.subject 1 11\r\nHello World\r\n',
        ];

        for (final message in messages) {
          final stream = Stream.value(Uint8List.fromList(utf8.encode(message)));
          final packets = await transformer.bind(stream).toList();

          // Should not contain INFO packets
          final infoPackets = packets.whereType<NatsS2CInfoPacket>();
          expect(infoPackets, isEmpty);
        }
      });
    });

    group('INFO Protocol Integration', () {
      test('should parse multiple INFO messages in sequence', () async {
        final info1 = {
          'server_id': 'server-1',
          'version': '2.9.0',
          'proto': 1,
        };

        final info2 = {
          'server_id': 'server-2',
          'version': '2.10.0',
          'proto': 1,
        };

        final combinedMessage =
            'INFO ${jsonEncode(info1)}\r\nINFO ${jsonEncode(info2)}\r\n';
        final stream = Stream.value(
          Uint8List.fromList(utf8.encode(combinedMessage)),
        );
        final packets = await transformer.bind(stream).toList();

        expect(packets, hasLength(2));

        final packet1 = packets[0] as NatsS2CInfoPacket;
        final packet2 = packets[1] as NatsS2CInfoPacket;

        expect(packet1.info.serverId, equals('server-1'));
        expect(packet2.info.serverId, equals('server-2'));
      });

      test('should parse INFO message with other protocol messages', () async {
        final infoJson = {
          'server_id': 'mixed-server',
          'version': '2.9.0',
          'proto': 1,
        };

        final mixedMessage =
            'INFO ${jsonEncode(infoJson)}\r\n'
            'PING\r\n'
            '+OK\r\n';

        final stream = Stream.value(
          Uint8List.fromList(utf8.encode(mixedMessage)),
        );
        final packets = await transformer.bind(stream).toList();

        expect(packets, hasLength(3));

        expect(packets[0], isA<NatsS2CInfoPacket>());
        expect(packets[1], isA<NatsS2CPingPacket>());
        expect(packets[2], isA<NatsS2COkPacket>());
      });
    });
  });

  group('ServerInfo JSON Serialization', () {
    test('should serialize ServerInfo to JSON correctly', () {
      final serverInfo = ServerInfo(
        serverId: 'test-server',
        serverName: 'Test Server',
        version: '2.9.0',
        proto: 1,
        go: 'go1.19.0',
        host: 'localhost',
        port: 4222,
        headers: true,
        maxPayload: 1048576,
        connectUrls: ['localhost:4223'],
        tlsRequired: true,
        tlsAvailable: true,
        tlsVerify: false,
        authRequired: true,
        nonce: 'test-nonce',
        clientId: 123,
        clientIp: '127.0.0.1',
        cluster: 'test-cluster',
        lameDuckMode: false,
      );

      final json = serverInfo.toJson();

      expect(json['server_id'], equals('test-server'));
      expect(json['server_name'], equals('Test Server'));
      expect(json['version'], equals('2.9.0'));
      expect(json['proto'], equals(1));
      expect(json['go'], equals('go1.19.0'));
      expect(json['host'], equals('localhost'));
      expect(json['port'], equals(4222));
      expect(json['headers'], isTrue);
      expect(json['max_payload'], equals(1048576));
      expect(json['connect_urls'], equals(['localhost:4223']));
      expect(json['tls_required'], isTrue);
      expect(json['tls_available'], isTrue);
      expect(json['tls_verify'], isFalse);
      expect(json['auth_required'], isTrue);
      expect(json['nonce'], equals('test-nonce'));
      expect(json['client_id'], equals(123));
      expect(json['client_ip'], equals('127.0.0.1'));
      expect(json['cluster'], equals('test-cluster'));
      expect(json['ldm'], isFalse);
    });

    test('should deserialize ServerInfo from JSON correctly', () {
      final json = {
        'server_id': 'deserialized-server',
        'server_name': 'Deserialized Server',
        'version': '2.10.0',
        'proto': 1,
        'host': '192.168.1.1',
        'port': 4222,
        'headers': false,
        'max_payload': 2097152,
        'connect_urls': ['192.168.1.2:4222'],
        'tls_required': false,
        'tls_available': true,
        'tls_verify': true,
        'auth_required': false,
        'nonce': null,
        'client_id': 456,
        'client_ip': null,
        'cluster': null,
        'ldm': true,
      };

      final serverInfo = ServerInfo.fromJson(json);

      expect(serverInfo.serverId, equals('deserialized-server'));
      expect(serverInfo.serverName, equals('Deserialized Server'));
      expect(serverInfo.version, equals('2.10.0'));
      expect(serverInfo.proto, equals(1));
      expect(serverInfo.host, equals('192.168.1.1'));
      expect(serverInfo.port, equals(4222));
      expect(serverInfo.headers, isFalse);
      expect(serverInfo.maxPayload, equals(2097152));
      expect(serverInfo.connectUrls, equals(['192.168.1.2:4222']));
      expect(serverInfo.tlsRequired, isFalse);
      expect(serverInfo.tlsAvailable, isTrue);
      expect(serverInfo.tlsVerify, isTrue);
      expect(serverInfo.authRequired, isFalse);
      expect(serverInfo.nonce, isNull);
      expect(serverInfo.clientId, equals(456));
      expect(serverInfo.clientIp, isNull);
      expect(serverInfo.cluster, isNull);
      expect(serverInfo.lameDuckMode, isTrue);
    });
  });

  group('HMSG Protocol Parsing', () {
    late NatsS2CTransformer transformer;

    setUp(() {
      transformer = NatsS2CTransformer();
    });

    test('should parse HMSG message with headers from NATS documentation example', () async {
      // Example from NATS protocol documentation:
      // HMSG FOO.BAR 9 BAZ.69 34 45␍␊NATS/1.0␍␊FoodGroup: vegetable␍␊␍␊Hello World␍␊
      final hmsgMessage = 'HMSG FOO.BAR 9 BAZ.69 34 45\r\nNATS/1.0\r\nFoodGroup: vegetable\r\n\r\nHello World\r\n';
      
      final stream = Stream.value(
        Uint8List.fromList(utf8.encode(hmsgMessage)),
      );
      final packets = await transformer.bind(stream).toList();

      expect(packets, hasLength(1));
      expect(packets[0], isA<NatsS2CHMsgPacket>());

      final hmsgPacket = packets[0] as NatsS2CHMsgPacket;
      
      // Verify message properties
      expect(hmsgPacket.subject, equals('FOO.BAR'));
      expect(hmsgPacket.sid, equals(9));
      expect(hmsgPacket.replyTo, equals('BAZ.69'));
      
      // Verify payload
      expect(hmsgPacket.payload, isNotNull);
      expect(utf8.decode(hmsgPacket.payload!), equals('Hello World'));
      
      // Verify headers
      expect(hmsgPacket.headers, isNotNull);
      expect(hmsgPacket.headers.containsKey('FoodGroup'), isTrue);
      expect(hmsgPacket.headers['FoodGroup'], equals('vegetable'));
    });

    test('should parse HMSG message without reply-to', () async {
      // Example without reply-to:
      // HMSG FOO.BAR 34 45␍␊NATS/1.0␍␊FoodGroup: vegetable␍␊␍␊Hello World␍␊
      final hmsgMessage = 'HMSG FOO.BAR 34 45\r\nNATS/1.0\r\nFoodGroup: vegetable\r\n\r\nHello World\r\n';
      
      final stream = Stream.value(
        Uint8List.fromList(utf8.encode(hmsgMessage)),
      );
      final packets = await transformer.bind(stream).toList();

      expect(packets, hasLength(1));
      expect(packets[0], isA<NatsS2CHMsgPacket>());

      final hmsgPacket = packets[0] as NatsS2CHMsgPacket;
      
      // Verify message properties
      expect(hmsgPacket.subject, equals('FOO.BAR'));
      expect(hmsgPacket.sid, equals(34));
      expect(hmsgPacket.replyTo, isNull);
      
      // Verify payload
      expect(hmsgPacket.payload, isNotNull);
      expect(utf8.decode(hmsgPacket.payload!), equals('Hello World'));
      
      // Verify headers
      expect(hmsgPacket.headers, isNotNull);
      expect(hmsgPacket.headers.containsKey('FoodGroup'), isTrue);
      expect(hmsgPacket.headers['FoodGroup'], equals('vegetable'));
    });

    test('should parse HMSG message with multiple headers', () async {
      // Example with multiple headers:
      // HMSG SUBJECT 12 56 78␍␊NATS/1.0␍␊Header1: value1␍␊Header2: value2␍␊Header3: value3␍␊␍␊Test payload␍␊
      final hmsgMessage = 'HMSG SUBJECT 12 56 78\r\nNATS/1.0\r\nHeader1: value1\r\nHeader2: value2\r\nHeader3: value3\r\n\r\nTest payload\r\n';
      
      final stream = Stream.value(
        Uint8List.fromList(utf8.encode(hmsgMessage)),
      );
      final packets = await transformer.bind(stream).toList();

      expect(packets, hasLength(1));
      expect(packets[0], isA<NatsS2CHMsgPacket>());

      final hmsgPacket = packets[0] as NatsS2CHMsgPacket;
      
      // Verify message properties
      expect(hmsgPacket.subject, equals('SUBJECT'));
      expect(hmsgPacket.sid, equals(12));
      expect(hmsgPacket.replyTo, isNull);
      
      // Verify payload
      expect(hmsgPacket.payload, isNotNull);
      expect(utf8.decode(hmsgPacket.payload!), equals('Test payload'));
      
      // Verify headers
      expect(hmsgPacket.headers, isNotNull);
      expect(hmsgPacket.headers.length, equals(3));
      expect(hmsgPacket.headers['Header1'], equals('value1'));
      expect(hmsgPacket.headers['Header2'], equals('value2'));
      expect(hmsgPacket.headers['Header3'], equals('value3'));
    });

    test('should parse HMSG message with empty payload', () async {
      // Example with empty payload:
      // HMSG SUBJECT 12 34␍␊NATS/1.0␍␊Header1: value1␍␊␍␊␍␊
      final hmsgMessage = 'HMSG SUBJECT 12 34\r\nNATS/1.0\r\nHeader1: value1\r\n\r\n\r\n';
      
      final stream = Stream.value(
        Uint8List.fromList(utf8.encode(hmsgMessage)),
      );
      final packets = await transformer.bind(stream).toList();

      expect(packets, hasLength(1));
      expect(packets[0], isA<NatsS2CHMsgPacket>());

      final hmsgPacket = packets[0] as NatsS2CHMsgPacket;
      
      // Verify message properties
      expect(hmsgPacket.subject, equals('SUBJECT'));
      expect(hmsgPacket.sid, equals(12));
      expect(hmsgPacket.replyTo, isNull);
      
      // Verify payload is empty
      expect(hmsgPacket.payload, isNotNull);
      expect(hmsgPacket.payload!.length, equals(0));
      
      // Verify headers
      expect(hmsgPacket.headers, isNotNull);
      expect(hmsgPacket.headers.length, equals(1));
      expect(hmsgPacket.headers['Header1'], equals('value1'));
    });
  });
}
