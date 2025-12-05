import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_nats/src/transformers/c2s.dart';
import 'package:dart_nats/src/transformers/packet/c2s.dart';
import 'package:dart_nats/src/transformers/types.dart';
import 'package:test/test.dart';

void main() {
  group('NatsC2STransformer', () {
    late NatsC2STransformer transformer;

    setUp(() {
      transformer = NatsC2STransformer();
    });

    group('CONNECT', () {
      test('should encode CONNECT packet with options', () async {
        final options = ConnectOptions(
          verbose: false,
          pedantic: false,
          tlsRequired: false,
          name: 'test-client',
          lang: 'dart',
          version: '1.0.0',
        );
        final packet = NatsC2SConnectPacket(options);

        final stream = Stream.value(
          packet as NatsC2SPacket,
        ).transform<Uint8List>(transformer);
        final result = await stream.first;

        final expected = utf8.encode(
          'CONNECT '
          // ignore: lines_longer_than_80_chars text
          '{"verbose":false,"pedantic":false,"tls_required":false,"name":"test-client","lang":"dart","version":"1.0.0"}'
          '\r\n',
        );
        expect(result, equals(expected));
      });
    });

    group('PUB', () {
      test('should encode PUB packet without reply-to', () async {
        const subject = 'FOO';
        const payload = 'Hello NATS!';
        final packet = NatsC2SPubPacket(subject, utf8.encode(payload));

        final stream = Stream.value(
          packet as NatsC2SPacket,
        ).transform<Uint8List>(transformer);
        final result = await stream.first;

        final expected = utf8.encode('PUB FOO 11\r\nHello NATS!\r\n');
        expect(result, equals(expected));
      });

      test('should encode PUB packet with reply-to', () async {
        const subject = 'FRONT.DOOR';
        const replyTo = 'JOKE.22';
        const payload = 'Knock Knock';
        final packet = NatsC2SPubPacket(
          subject,
          utf8.encode(payload),
          replyTo: replyTo,
        );

        final stream = Stream.value(
          packet as NatsC2SPacket,
        ).transform<Uint8List>(transformer);
        final result = await stream.first;

        final expected = utf8.encode(
          'PUB FRONT.DOOR JOKE.22 11\r\nKnock Knock\r\n',
        );
        expect(result, equals(expected));
      });

      test('should encode PUB packet with empty payload', () async {
        const subject = 'NOTIFY';
        final packet = NatsC2SPubPacket(subject, Uint8List(0));

        final stream = Stream.value(
          packet as NatsC2SPacket,
        ).transform<Uint8List>(transformer);
        final result = await stream.first;

        final expected = utf8.encode('PUB NOTIFY 0\r\n\r\n');
        expect(result, equals(expected));
      });
    });

    group('HPUB', () {
      test('should encode HPUB packet with single header', () async {
        const subject = 'FOO';
        const payload = 'Hello NATS!';
        final headers = {'Bar': 'Baz'};
        final packet = NatsC2SHPubPacket(
          subject,
          headers,
          utf8.encode(payload),
        );

        final stream = Stream.value(
          packet as NatsC2SPacket,
        ).transform<Uint8List>(transformer);
        final result = await stream.first;

        final expected = utf8.encode(
          'HPUB FOO 22 33\r\nNATS/1.0\r\nBar: Baz\r\n\r\nHello NATS!\r\n',
        );
        expect(result, equals(expected));
      });

      test(
        'should encode HPUB packet with reply-to and multiple headers',
        () async {
          const subject = 'FRONT.DOOR';
          const replyTo = 'JOKE.22';
          const payload = 'Knock Knock';
          final headers = {
            'BREAKFAST': 'donut',
            'LUNCH': 'burger',
          };
          final packet = NatsC2SHPubPacket(
            subject,
            headers,
            utf8.encode(payload),
            replyTo: replyTo,
          );

          final stream = Stream.value(
            packet as NatsC2SPacket,
          ).transform<Uint8List>(transformer);
          final result = await stream.first;

          final expected = utf8.encode(
            'HPUB FRONT.DOOR JOKE.22 45 56\r\nNATS/1.0\r\nBREAKFAST: donut\r\nLUNCH: burger\r\n\r\nKnock Knock\r\n',
          );
          expect(result, equals(expected));
        },
      );

      test('should encode HPUB packet with empty payload', () async {
        const subject = 'NOTIFY';
        final headers = {'Bar': 'Baz'};
        final packet = NatsC2SHPubPacket(subject, headers, Uint8List(0));

        final stream = Stream.value(
          packet as NatsC2SPacket,
        ).transform<Uint8List>(transformer);
        final result = await stream.first;

        final expected = utf8.encode(
          'HPUB NOTIFY 22 22\r\nNATS/1.0\r\nBar: Baz\r\n\r\n\r\n',
        );
        expect(result, equals(expected));
      });

      // TODO: Fix this test - Map can't have duplicate keys, so we need to implement
      // support for multiple values per header key
      /*
      test(
        'should encode HPUB packet with multiple values for same header',
        () async {
          const subject = 'MORNING.MENU';
          const payload = 'Yum!';
          final headers = {
            'BREAKFAST': 'eggs',
          };
          final packet = NatsC2SHPubPacket(
            subject,
            headers,
            utf8.encode(payload),
          );

          final stream = Stream.value(
            packet as NatsC2SPacket,
          ).transform<Uint8List>(transformer);
          final result = await stream.first;

          // Note: Map can't have duplicate keys, so only one value is kept
          final expected = utf8.encode(
            'HPUB MORNING.MENU 47 51\r\nNATS/1.0\r\nBREAKFAST: donut\r\nBREAKFAST: eggs\r\n\r\nYum!\r\n',
          );
          expect(result, equals(expected));
        },
      );
      */
    });

    group('SUB', () {
      test('should encode SUB packet without queue group', () async {
        const subject = 'FOO';
        const sid = 1;
        final packet = NatsC2SSubPacket(subject, sid);

        final stream = Stream.value(
          packet as NatsC2SPacket,
        ).transform<Uint8List>(transformer);
        final result = await stream.first;

        final expected = utf8.encode('SUB FOO 1\r\n');
        expect(result, equals(expected));
      });

      test('should encode SUB packet with queue group', () async {
        const subject = 'BAR';
        const queueGroup = 'G1';
        const sid = 44;
        final packet = NatsC2SSubPacket(subject, sid, queueGroup: queueGroup);

        final stream = Stream.value(
          packet as NatsC2SPacket,
        ).transform<Uint8List>(transformer);
        final result = await stream.first;

        final expected = utf8.encode('SUB BAR G1 44\r\n');
        expect(result, equals(expected));
      });
    });

    group('UNSUB', () {
      test('should encode UNSUB packet without max_msgs', () async {
        const sid = 1;
        final packet = NatsC2SUnsubPacket(sid);

        final stream = Stream.value(
          packet as NatsC2SPacket,
        ).transform<Uint8List>(transformer);
        final result = await stream.first;

        final expected = utf8.encode('UNSUB 1\r\n');
        expect(result, equals(expected));
      });

      test('should encode UNSUB packet with max_msgs', () async {
        const sid = 1;
        const maxMsgs = 5;
        final packet = NatsC2SUnsubPacket(sid, maxMsgs: maxMsgs);

        final stream = Stream.value(
          packet as NatsC2SPacket,
        ).transform<Uint8List>(transformer);
        final result = await stream.first;

        final expected = utf8.encode('UNSUB 1 5\r\n');
        expect(result, equals(expected));
      });
    });

    group('PING', () {
      test('should encode PING packet', () async {
        final packet = NatsC2SPingPacket();

        final stream = Stream.value(
          packet as NatsC2SPacket,
        ).transform<Uint8List>(transformer);
        final result = await stream.first;

        final expected = utf8.encode('PING\r\n');
        expect(result, equals(expected));
      });
    });

    group('PONG', () {
      test('should encode PONG packet', () async {
        final packet = NatsC2SPongPacket();

        final stream = Stream.value(
          packet as NatsC2SPacket,
        ).transform<Uint8List>(transformer);
        final result = await stream.first;

        final expected = utf8.encode('PONG\r\n');
        expect(result, equals(expected));
      });
    });

    group('Stream processing', () {
      test('should process multiple packets in stream', () async {
        final packets = [
          NatsC2SPingPacket(),
          NatsC2SPongPacket(),
          NatsC2SPubPacket('TEST', utf8.encode('data')),
        ];

        final stream = Stream.fromIterable(packets).transform(transformer);
        final results = await stream.toList();

        expect(results.length, equals(3));
        expect(results[0], equals(utf8.encode('PING\r\n')));
        expect(results[1], equals(utf8.encode('PONG\r\n')));
        expect(results[2], equals(utf8.encode('PUB TEST 4\r\ndata\r\n')));
      });
    });
  });
}
