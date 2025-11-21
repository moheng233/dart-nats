import 'package:test/test.dart';
import 'package:dart_nats/dart_nats.dart';

/// KV create tests
/// Requires a running NATS server with JetStream enabled
void main() {
  group('KV Create', () {
    test('create sets stream max_msgs_per_subject from history', () async {
      final client = NatsClient();
      await client.connect(Uri.parse('nats://localhost:4222'));
      await client.waitUntilConnected();

      final kvm = await Kvm.fromClient(client);
      final bucketName = 'test-kv-create';
      final opts = KvOptions(history: 5);

      // Ensure delete before test to avoid collision
      try {
        await kvm.delete(bucketName);
      } catch (_) {}

      await kvm.create(bucketName, opts);
      final jsm = await jetstreamManager(client, JetStreamManagerOptions());
      final info = await jsm.getStreamInfo('KV_$bucketName');
      expect(info.config.maxMsgsPerSubject, equals(opts.history));

      // cleanup
      await kvm.delete(bucketName);
      await client.close();
    });
  });
}
