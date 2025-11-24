// ignore_for_file: avoid_print example

import 'package:dart_nats/dart_nats.dart';

void main() async {
  final client = NatsClient();
  await client.connect(Uri.parse('nats://localhost:4222'));
  final sub = client.sub('subject1');
  await client.pubString('subject1', 'message1');
  final data = await sub.stream.first;

  print(data.string);
  await client.unSub(sub);
  await client.close();
}
