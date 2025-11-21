import 'package:dart_nats/dart_nats.dart';

void main() async {
  var client = NatsClient();
  await client.connect(Uri.parse('nats://localhost:4222'));
  var sub = client.sub('subject1');
  client.pubString('subject1', 'message1');
  var data = await sub.stream.first;

  print(data.string);
  client.unSub(sub);
  await client.close();
}
