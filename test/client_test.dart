import 'dart:async';
import 'dart:io';

import 'package:dart_nats/dart_nats.dart';
import 'package:test/test.dart';

import 'util/mock_transport.dart';

void main() {
  group('NatsClient connection', () {
    test('should connect successfully', () async {
      final transport = MockTransport();

      final client = NatsClient(
        Uri.parse('nats://localhost:4222'),
        autoConnect: false,
        transportFactory: createSingleMockTransportFactory(transport),
      );

      // Start connection in background
      final connectFuture = client.connect();

      // Wait a bit for the connection to start
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Simulate server sending INFO
      transport.simulateInfo();

      // Connection should complete
      await connectFuture;

      expect(client.state, NatsConnectionState.connected);
      expect(client.serverInfo, isNotNull);
      expect(client.serverInfo!.serverId, 'TEST_SERVER');

      await client.close();
    });

    test('should fail connection on server error', () async {
      final transport = MockTransport();

      final client = NatsClient(
        Uri.parse('nats://localhost:4222'),
        autoConnect: false,
        autoReconnect: false,
        transportFactory: createSingleMockTransportFactory(transport),
      );

      // Start connection
      final connectFuture = client.connect();

      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Simulate server sending error
      transport.simulateError('Authorization Violation');

      // Connection should fail
      await expectLater(connectFuture, throwsA(isA<NatsException>()));

      await client.close();
    });

    test('should fail when transport factory throws', () async {
      final client = NatsClient(
        Uri.parse('nats://localhost:4222'),
        autoConnect: false,
        autoReconnect: false,
        transportFactory: createFailingTransportFactory('Connection refused'),
      );

      await expectLater(client.connect(), throwsA(isA<SocketException>()));
    });
  });

  group('NatsClient pub/sub', () {
    test('should subscribe and receive messages', () async {
      final transport = MockTransport();

      final client = NatsClient(
        Uri.parse('nats://localhost:4222'),
        autoConnect: false,
        transportFactory: createSingleMockTransportFactory(transport),
      );

      final connectFuture = client.connect();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      transport.simulateInfo();
      await connectFuture;

      // Subscribe to a subject
      final sub = client.sub('test.subject');
      expect(sub.subject, 'test.subject');

      // Simulate server sending a message
      // sid is 2 because inbox subscription is sid 1
      transport.simulateMsg(
        subject: 'test.subject',
        sid: 2,
        payload: 'Hello World',
      );

      // Should receive the message
      final msg = await sub.stream.first;
      expect(msg.subject, 'test.subject');
      expect(msg.string, 'Hello World');

      await client.close();
    });

    test('should publish messages', () async {
      final transport = MockTransport();

      final client = NatsClient(
        Uri.parse('nats://localhost:4222'),
        autoConnect: false,
        transportFactory: createSingleMockTransportFactory(transport),
      );

      final connectFuture = client.connect();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      transport.simulateInfo();
      await connectFuture;

      // Listen to output to verify publish
      final outputCompleter = Completer<String>();
      transport.outputStream.listen((data) {
        final str = String.fromCharCodes(data);
        if (str.contains('PUB')) {
          outputCompleter.complete(str);
        }
      });

      // Publish a message
      client.pubString('test.subject', 'Hello World');

      // Verify the PUB command was sent
      final output = await outputCompleter.future.timeout(
        const Duration(seconds: 1),
      );
      expect(output, contains('PUB test.subject'));
      expect(output, contains('Hello World'));

      await client.close();
    });
  });

  group('NatsClient auto reconnect', () {
    test('should reconnect after disconnect', () async {
      var connectCount = 0;
      final transports = <MockTransport>[];

      final client = NatsClient(
        Uri.parse('nats://localhost:4222'),
        autoConnect: false,
        reconnectDelay: const Duration(milliseconds: 100),
        transportFactory: (uri) async {
          connectCount++;
          final transport = MockTransport();
          transports.add(transport);
          // Auto send INFO after a delay
          Future.delayed(
            const Duration(milliseconds: 10),
            transport.simulateInfo,
          );
          return transport;
        },
      );

      // First connection
      await client.connect();
      expect(client.state, NatsConnectionState.connected);
      expect(connectCount, 1);

      // Simulate disconnect
      transports[0].simulateDisconnect();

      // Wait for state change
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(client.state, NatsConnectionState.disconnected);

      // Wait for reconnect
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(connectCount, 2);
      expect(client.state, NatsConnectionState.connected);

      await client.close();
    });

    test(
      'should stop reconnecting after max attempts when connection fails',
      () async {
        var connectCount = 0;
        MockTransport? firstTransport;
        final reconnectTransports = <MockTransport>[];

        final client = NatsClient(
          Uri.parse('nats://localhost:4222'),
          autoConnect: false,
          maxReconnectAttempts: 3,
          reconnectDelay: const Duration(milliseconds: 50),
          transportFactory: (uri) async {
            connectCount++;
            if (connectCount == 1) {
              // First connection succeeds
              firstTransport = MockTransport();
              Future.delayed(const Duration(milliseconds: 10), () {
                firstTransport!.simulateInfo();
              });
              return firstTransport!;
            } else {
              // Subsequent connections: transport created, simulate disconnect
              final transport = MockTransport();
              reconnectTransports.add(transport);
              // Simulate immediate connection failure
              Future.delayed(
                const Duration(milliseconds: 10),
                transport.simulateDisconnect,
              );
              return transport;
            }
          },
        );

        // First connection succeeds
        await client.connect();
        expect(client.state, NatsConnectionState.connected);
        expect(connectCount, 1);

        // Disconnect
        firstTransport!.simulateDisconnect();

        // Wait for all reconnect attempts
        // Each attempt: 50ms delay + 10ms until disconnect
        await Future<void>.delayed(const Duration(milliseconds: 500));

        // Should have tried: 1 initial + 3 reconnects = 4 total
        expect(connectCount, 4);

        await client.close();
      },
    );

    test('should resubscribe after reconnect', () async {
      var connectCount = 0;
      final transports = <MockTransport>[];

      final client = NatsClient(
        Uri.parse('nats://localhost:4222'),
        autoConnect: false,
        reconnectDelay: const Duration(milliseconds: 100),
        transportFactory: (uri) async {
          connectCount++;
          final transport = MockTransport();
          transports.add(transport);
          Future.delayed(
            const Duration(milliseconds: 10),
            transport.simulateInfo,
          );
          return transport;
        },
      );

      // First connection
      await client.connect();

      // Subscribe to a subject
      final sub = client.sub('test.subject');
      final messages = <NatsMessage>[];
      sub.stream.listen(messages.add);

      // Simulate disconnect
      transports[0].simulateDisconnect();

      // Wait for reconnect
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(connectCount, 2);
      expect(client.state, NatsConnectionState.connected);

      // Wait a bit for resubscription
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Send message on new transport (sid should be same)
      transports[1].simulateMsg(
        subject: 'test.subject',
        sid: sub.sid,
        payload: 'After reconnect',
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Should receive the message
      expect(messages, hasLength(1));
      expect(messages[0].string, 'After reconnect');

      await client.close();
    });
  });

  group('NatsClient request/response', () {
    test('should send request and receive response', () async {
      final transport = MockTransport();

      final client = NatsClient(
        Uri.parse('nats://localhost:4222'),
        autoConnect: false,
        transportFactory: createSingleMockTransportFactory(transport),
      );

      final connectFuture = client.connect();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      transport.simulateInfo();
      await connectFuture;

      // Start request in background
      final requestFuture = client.requestString(
        'service.echo',
        'Hello',
        timeout: const Duration(seconds: 5),
      );

      // Wait for request to be sent
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Simulate response on inbox
      // Inbox subscription is sid 1, and the reply subject is _INBOX.<prefix>.<id>
      transport.simulateMsg(
        subject: '${client.inboxPrefix}.0',
        sid: 1,
        payload: 'Echo: Hello',
      );

      final response = await requestFuture;
      expect(response.string, 'Echo: Hello');

      await client.close();
    });

    test('should timeout on no response', () async {
      final transport = MockTransport();

      final client = NatsClient(
        Uri.parse('nats://localhost:4222'),
        autoConnect: false,
        transportFactory: createSingleMockTransportFactory(transport),
      );

      final connectFuture = client.connect();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      transport.simulateInfo();
      await connectFuture;

      // Send request with short timeout
      final requestFuture = client.requestString(
        'service.echo',
        'Hello',
        timeout: const Duration(milliseconds: 100),
      );

      // Don't send response - should timeout
      await expectLater(requestFuture, throwsA(isA<TimeoutException>()));

      await client.close();
    });
  });

  group('NatsClient ping/pong', () {
    test('should respond to PING with PONG', () async {
      final transport = MockTransport();

      final client = NatsClient(
        Uri.parse('nats://localhost:4222'),
        autoConnect: false,
        transportFactory: createSingleMockTransportFactory(transport),
      );

      final connectFuture = client.connect();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      transport.simulateInfo();
      await connectFuture;

      // Listen for PONG response
      final pongCompleter = Completer<bool>();
      transport.outputStream.listen((data) {
        final str = String.fromCharCodes(data);
        if (str.contains('PONG')) {
          pongCompleter.complete(true);
        }
      });

      // Send PING from server
      transport.simulatePing();

      // Should receive PONG
      final gotPong = await pongCompleter.future.timeout(
        const Duration(seconds: 1),
      );
      expect(gotPong, isTrue);

      await client.close();
    });
  });
}
