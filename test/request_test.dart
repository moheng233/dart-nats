import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_nats/dart_nats.dart';
import 'package:test/test.dart';

void main() {
  group('all', () {
    test('simple', () async {
      final client = NatsClient();
      await client.connect(Uri.parse('nats://localhost:4222'), retryInterval: 1);
      final sub = client.sub('subject1');
      await client.pub('subject1', Uint8List.fromList('message1'.codeUnits));
      final msg = await sub.stream.first;
      expect(String.fromCharCodes(msg.byte), equals('message1'));
      await client.close();
    });
    test('respond', () async {
      final server = NatsClient();
      await server.connect(Uri.parse('nats://localhost:4222'));
      final service = server.sub('service');
      service.stream.listen((m) {
        m.respondString('respond');
      });

      final requester = NatsClient();
      await requester.connect(Uri.parse('nats://localhost:4222'));
      final inbox = newInbox();
      final inboxSub = requester.sub(inbox);

      requester.pubString('service', 'request', replyTo: inbox);

      final receive = await inboxSub.stream.first;

      await requester.close();
      await server.close();
      expect(receive.string, equals('respond'));
    });
    test('request', () async {
      final server = NatsClient();
      await server.connect(Uri.parse('nats://localhost:4222'));
      final service = server.sub('service');
      unawaited(service.stream.first.then((m) {
        m.respond(Uint8List.fromList('respond'.codeUnits));
      }));

      final client = NatsClient();
      await client.connect(Uri.parse('nats://localhost:4222'));
      final receive = await client.request(
          'service', Uint8List.fromList('request'.codeUnits));

      await client.close();
      await server.close();
      expect(receive.string, equals('respond'));
    });
    test('custom inbox', () async {
      final server = NatsClient();
      await server.connect(Uri.parse('nats://localhost:4222'));
      final service = server.sub('service');
      unawaited(service.stream.first.then((m) {
        m.respond(Uint8List.fromList('respond'.codeUnits));
      }));

      final client = NatsClient();
      client.inboxPrefix = '_INBOX.test_test';
      await client.connect(Uri.parse('nats://localhost:4222'));
      final receive = await client.request(
          'service', Uint8List.fromList('request'.codeUnits));

      await client.close();
      await server.close();
      expect(receive.string, equals('respond'));
    });
    test('request with timeout', () async {
      final server = NatsClient();
      await server.connect(Uri.parse('nats://localhost:4222'));
      final service = server.sub('service');
      unawaited(service.stream.first.then((m) {
        sleep(const Duration(seconds: 1));
        m.respond(Uint8List.fromList('respond'.codeUnits));
      }));

      final client = NatsClient();
      await client.connect(Uri.parse('nats://localhost:4222'));
      final receive = await client.request(
          'service', Uint8List.fromList('request'.codeUnits),
          timeout: const Duration(seconds: 3));

      await client.close();
      await server.close();
      expect(receive.string, equals('respond'));
    });
    test('request with timeout exception', () async {
      final server = NatsClient();
      await server.connect(Uri.parse('nats://localhost:4222'));
      final service = server.sub('service');
      unawaited(service.stream.first.then((m) {
        sleep(const Duration(seconds: 5));
        m.respond(Uint8List.fromList('respond'.codeUnits));
      }));

      final client = NatsClient();
      var gotit = false;
      await client.connect(Uri.parse('nats://localhost:4222'));
      try {
        await client.request('service', Uint8List.fromList('request'.codeUnits));
      } on TimeoutException {
        gotit = true;
      }
      await client.close();
      await service.close();
      await server.close();
      expect(gotit, equals(true));
    });
    test('future request to 2 service', () async {
      final server = NatsClient();
      await server.connect(Uri.parse('nats://localhost:4222'));
      final service1 = server.sub('service1');
      service1.stream.listen((m) {
        m.respond(Uint8List.fromList('respond1'.codeUnits));
      });
      final service2 = server.sub('service2');
      service2.stream.listen((m) {
        m.respond(Uint8List.fromList('respond2'.codeUnits));
      });

      final client = NatsClient();
      await client.connect(Uri.parse('nats://localhost:4222'));
      Future<Message> receive1;
      Future<Message> receive2;
      unawaited(receive2 =
          client.request('service2', Uint8List.fromList('request'.codeUnits)));
      unawaited(receive1 =
          client.request('service1', Uint8List.fromList('request'.codeUnits)));
      final r1 = await receive1;
      final r2 = await receive2;
      await client.close();
      await server.close();
      expect(r1.string, equals('respond1'));
      expect(r2.string, equals('respond2'));
    });
  });
}
