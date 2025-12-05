// ignore_for_file: avoid_print example

import 'package:dart_nats/dart_nats.dart';

void main() async {
  final stopwatch = Stopwatch()..start();

  print('[${stopwatch.elapsedMilliseconds}ms] Starting NATS client example...');

  final client = await NatsClient.create(Uri.parse('nats://localhost:4222'));
  print('[${stopwatch.elapsedMilliseconds}ms] Connected to NATS server');
  print(
    '[${stopwatch.elapsedMilliseconds}ms] Server info: ${client.serverInfo}',
  );

  final sub = client.sub('subject1');
  print('[${stopwatch.elapsedMilliseconds}ms] Subscribed to "subject1"');

  client.pubString('subject1', 'message1');
  print('[${stopwatch.elapsedMilliseconds}ms] Published message to "subject1"');

  print('[${stopwatch.elapsedMilliseconds}ms] Waiting for message...');
  final data = await sub.stream.first;
  print(
    '[${stopwatch.elapsedMilliseconds}ms] Received message: ${data.string}',
  );

  client.unSub(sub);
  print('[${stopwatch.elapsedMilliseconds}ms] Unsubscribed from "subject1"');

  await client.close();
  print('[${stopwatch.elapsedMilliseconds}ms] Connection closed');

  stopwatch.stop();
  print('[${stopwatch.elapsedMilliseconds}ms] Example completed');
}
