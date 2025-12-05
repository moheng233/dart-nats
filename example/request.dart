// ignore_for_file: avoid_print example

import 'package:dart_nats/dart_nats.dart';

void main() async {
  final stopwatch = Stopwatch()..start();

  print(
    '[${stopwatch.elapsedMilliseconds}ms] Starting request/response example...',
  );

  // Create two clients
  final client1 = await NatsClient.create(Uri.parse('nats://localhost:4222'));
  print('[${stopwatch.elapsedMilliseconds}ms] Client1 connected (requester)');

  final client2 = await NatsClient.create(Uri.parse('nats://localhost:4222'));
  print('[${stopwatch.elapsedMilliseconds}ms] Client2 connected (responder)');

  // Client2 subscribes to a subject and responds to requests
  final sub = client2.sub('service.echo');
  print(
    '[${stopwatch.elapsedMilliseconds}ms] Client2 subscribed to "service.echo"',
  );

  // Start listening for requests in the background
  sub.stream.listen((msg) {
    print(
      '[${stopwatch.elapsedMilliseconds}ms] Client2 received request: ${msg.string}',
    );
    if (msg.replyTo != null) {
      // Send response back
      final response = 'Echo: ${msg.string}';
      client2.pubString(msg.replyTo!, response);
      print(
        '[${stopwatch.elapsedMilliseconds}ms] Client2 sent response: $response',
      );
    }
  });

  // Give some time for subscription to be established
  await Future<void>.delayed(const Duration(milliseconds: 100));

  // Client1 sends a request and waits for response
  print('[${stopwatch.elapsedMilliseconds}ms] Client1 sending request...');
  final response = await client1.requestString(
    'service.echo',
    'Hello NATS!',
    timeout: const Duration(seconds: 5),
  );
  print(
    '[${stopwatch.elapsedMilliseconds}ms] Client1 received response: ${response.string}',
  );

  // Send another request
  print(
    '[${stopwatch.elapsedMilliseconds}ms] Client1 sending second request...',
  );
  final response2 = await client1.requestString(
    'service.echo',
    'How are you?',
    timeout: const Duration(seconds: 5),
  );
  print(
    '[${stopwatch.elapsedMilliseconds}ms] Client1 received response: ${response2.string}',
  );

  // Cleanup
  client2.unSub(sub);
  print('[${stopwatch.elapsedMilliseconds}ms] Client2 unsubscribed');

  await client1.close();
  print('[${stopwatch.elapsedMilliseconds}ms] Client1 closed');

  await client2.close();
  print('[${stopwatch.elapsedMilliseconds}ms] Client2 closed');

  stopwatch.stop();
  print('[${stopwatch.elapsedMilliseconds}ms] Example completed');
}
