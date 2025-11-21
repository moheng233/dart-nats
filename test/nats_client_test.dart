import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_nats/dart_nats.dart';
import 'package:test/test.dart';

void main() {
  group('all', () {
    test('simple', () async {
      final client = NatsClient();
      await client.connect(Uri.parse('ws://localhost:8080'));
      final sub = client.sub('subject1');
      await client.pub('subject1', Uint8List.fromList('message1'.codeUnits));
      final msg = await sub.stream.first;
      await client.close();
      expect(String.fromCharCodes(msg.byte), equals('message1'));
    });
    test('newInbox', () {
      //just loop generate with out error
      var i = 0;
      for (i = 0; i < 10000; i++) {
        newInbox();
      }
      expect(i, 10000);
    });
    test('nuid not dup', () {
      var dup = false;
      final nuid1 = Nuid();
      final nuid2 = Nuid();
      for (var i = 0; i < 10000; i++) {
        final n1 = nuid1.next();
        final n2 = nuid2.next();
        if (n1 == n2) dup = true;
      }
      for (var i = 0; i < 10000; i++) {
        final nuid1 = Nuid();
        final nuid2 = Nuid();
        final n1 = nuid1.next();
        final n2 = nuid2.next();
        if (n1 == n2) dup = true;
      }
      expect(dup, false);
    });
    test('pub with Uint8List', () async {
      final client = NatsClient();
      await client.connect(Uri.parse('ws://localhost:8080'));
      final sub = client.sub('subject1');
      final msgByte = Uint8List.fromList([1, 2, 3, 129, 130]);
      await client.pub('subject1', msgByte);
      final msg = await sub.stream.first;
      await client.close();
      expect(msg.byte, equals(msgByte));
    });
    test('pub with Uint8List include return and  new line', () async {
      final client = NatsClient();
      await client.connect(Uri.parse('ws://localhost:8080'));
      final sub = client.sub('subject1');
      final msgByte = Uint8List.fromList([
        1,
        10,
        3,
        13,
        10,
        13,
        130,
        1,
        10,
        3,
        13,
        10,
        13,
        130,
      ]);
      await client.pub('subject1', msgByte);
      final msg = await sub.stream.first;
      await client.close();
      expect(msg.byte, equals(msgByte));
    });
    test('byte huge data', () async {
      final client = NatsClient();
      await client.connect(Uri.parse('ws://localhost:8080'));
      final sub = client.sub('subject1');
      final msgByte = Uint8List.fromList(
        List<int>.generate(1024 + 1024 * 4, (i) => i % 256),
      );
      await client.pub('subject1', msgByte);
      final msg = await sub.stream.first;
      await client.close();
      expect(msg.byte, equals(msgByte));
    });
    test('UTF8', () async {
      final client = NatsClient();
      await client.connect(Uri.parse('ws://localhost:8080'));
      final sub = client.sub('subject1');
      final thaiString = utf8.encode('ทดสอบ');
      await client.pub('subject1', Uint8List.fromList(thaiString));
      final msg = await sub.stream.first;
      await client.close();
      expect(msg.byte, equals(thaiString));
    });
    test('pubString ascii', () async {
      final client = NatsClient();
      await client.connect(Uri.parse('ws://localhost:8080'));
      final sub = client.sub('subject1');
      await client.pubString('subject1', 'testtesttest');
      final msg = await sub.stream.first;
      await client.close();
      expect(msg.string, equals('testtesttest'));
    });
    test('pubString Thai', () async {
      final client = NatsClient();
      await client.connect(Uri.parse('ws://localhost:8080'));
      final sub = client.sub('subject1');
      await client.pubString('subject1', 'ทดสอบ');
      final msg = await sub.stream.first;
      await client.close();
      expect(msg.string, equals('ทดสอบ'));
    });
    test('delay connect', () async {
      final client = NatsClient();
      final sub = client.sub('subject1');
      await client.pubString('subject1', 'message1');
      await client.connect(Uri.parse('ws://localhost:8080'));
      final msg = await sub.stream.first;
      await client.close();
      expect(msg.string, equals('message1'));
    });
    test('pub with no buffer ', () async {
      final client = NatsClient();
      await client.connect(Uri.parse('ws://localhost:8080'));
      final sub = client.sub('subject1');
      await Future.delayed(const Duration(seconds: 1));
      await client.pubString('subject1', 'message1', buffer: false);
      final msg = await sub.stream.first;
      await client.close();
      expect(msg.string, equals('message1'));
    });
    test('multiple sub ', () async {
      final client = NatsClient();
      await client.connect(Uri.parse('ws://localhost:8080'));
      final sub1 = client.sub('subject1');
      final sub2 = client.sub('subject2');
      await Future.delayed(const Duration(seconds: 1));
      client
        ..pubString('subject1', 'message1')
        ..pubString('subject2', 'message2');
      final msg1 = await sub1.stream.first;
      final msg2 = await sub2.stream.first;
      await client.close();
      expect(msg1.string, equals('message1'));
      expect(msg2.string, equals('message2'));
    });
    test('Wildcard sub * ', () async {
      final client = NatsClient();
      await client.connect(Uri.parse('ws://localhost:8080'));
      final sub = client.sub('subject1.*');
      await client.pubString('subject1.1', 'message1');
      await client.pubString('subject1.2', 'message2');
      final msgStream = sub.stream.asBroadcastStream();
      final msg1 = await msgStream.first;
      final msg2 = await msgStream.first;
      await client.close();
      expect(msg1.string, equals('message1'));
      expect(msg2.string, equals('message2'));
    });
    test('Wildcard sub > ', () async {
      final client = NatsClient();
      await client.connect(Uri.parse('ws://localhost:8080'));
      final sub = client.sub('subject1.>');
      await client.pubString('subject1.a.1', 'message1');
      await client.pubString('subject1.b.2', 'message2');
      final msgStream = sub.stream.asBroadcastStream();
      final msg1 = await msgStream.first;
      final msg2 = await msgStream.first;
      await client.close();
      expect(msg1.string, equals('message1'));
      expect(msg2.string, equals('message2'));
    });
    test('unsub after connect', () async {
      final client = NatsClient();
      await client.connect(Uri.parse('ws://localhost:8080'));
      var sub = client.sub('subject1');
      await client.pubString('subject1', 'message1');
      var msg = await sub.stream.first;
      await client.unSub(sub);
      expect(msg.string, equals('message1'));

      sub = client.sub('subject1');
      await client.pubString('subject1', 'message1');
      msg = await sub.stream.first;
      sub.unSub();
      expect(msg.string, equals('message1'));

      await client.close();
    });
    test('unsub before connect', () async {
      final client = NatsClient();
      await client.connect(Uri.parse('ws://localhost:8080'));
      var sub = client.sub('subject1');
      client.unSub(sub);

      sub = client.sub('subject1');
      sub.unSub();
      await client.close();
      expect(1, 1);
    });
    test('get max payload', () async {
      final client = NatsClient();
      await client.connect(Uri.parse('ws://localhost:8080'));

      //todo wait for connected
      await Future.delayed(const Duration(seconds: 2));
      final max = client.maxPayload();
      await client.close();

      expect(max, isNotNull);
    });
    test('sub continuous msg', () async {
      final client = NatsClient();
      await client.connect(Uri.parse('ws://localhost:8080'));
      final sub = client.sub('sub');
      var r = 0;
      const iteration = 100;
      sub.stream.listen((msg) {
        r++;
      });
      for (var i = 0; i < iteration; i++) {
        unawaited(client.pubString('sub', i.toString()));
        // await Future.delayed(Duration(milliseconds: 10));
      }
      await Future.delayed(const Duration(seconds: 1));
      await client.close();
      expect(r, equals(iteration));
    });
    test('sub defect 13 binary', () async {
      final client = NatsClient();
      await client.connect(Uri.parse('ws://localhost:8080'));
      final sub = client.sub('sub');
      var r = 0;
      const iteration = 100;
      sub.stream.listen((msg) {
        r++;
      });
      for (var i = 0; i < iteration; i++) {
        unawaited(client.pub('sub', Uint8List.fromList([10, 13, 10])));
        // await Future.delayed(Duration(milliseconds: 10));
      }
      await Future.delayed(const Duration(seconds: 1));
      await client.close();
      expect(r, equals(iteration));
    });
  });
}
