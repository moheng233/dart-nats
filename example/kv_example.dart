import 'dart:typed_data';
import 'dart:async';
import 'package:dart_nats/dart_nats.dart';

/// Example demonstrating KV (Key-Value) Store functionality
///
/// This example shows how to:
/// 1. Create and manage KV buckets
/// 2. Put and get key-value pairs
/// 3. Delete and purge keys
/// 4. List keys in a bucket
/// 5. Get bucket status
///
/// Prerequisites:
/// - NATS server with JetStream enabled
/// - Run: docker-compose up -d (from repository root)
///
/// Run this example:
/// dart example/kv_example.dart

void main() async {
  // Create a NATS client
  var client = NatsClient();

  try {
    // Connect to NATS server
    print('Connecting to NATS server...');
    await measureOp('client.connect', () async => await client.connect(Uri.parse('nats://localhost:4222')));
    print('Connected to NATS server');

    // Wait for connection
    await measureOp('client.waitUntilConnected', () async => await client.waitUntilConnected());

    // Example 1: Create KV Manager and Bucket
    await measureOp('Example 1 - Create KV Manager and Bucket', () async {
      await createBucketExample(client);
    });

    // Example 2: Put and Get Operations
    await measureOp('Example 2 - Put and Get Operations', () async {
      await putGetExample(client);
    });

    // Example 3: Delete and Purge
    await measureOp('Example 3 - Delete and Purge', () async {
      await deleteExample(client);
    });

    // Example 4: List Keys
    await measureOp('Example 4 - List Keys', () async {
      await listKeysExample(client);
    });

    print('\n✓ All KV examples completed successfully!');
  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
    print('\nConnection closed');
  }
}

/// Helper wrapper to measure and print duration of async operations
Future<T> measureOp<T>(String name, Future<T> Function() fn) async {
  final sw = Stopwatch()..start();
  try {
    final res = await fn();
    sw.stop();
    print('\n[name: $name] Time: ${sw.elapsedMilliseconds} ms');
    return res;
  } catch (e) {
    sw.stop();
    print('\n[name: $name] Time: ${sw.elapsedMilliseconds} ms  ERROR: $e');
    rethrow;
  }
}

/// Example 1: Create KV Manager and Bucket
Future<void> createBucketExample(NatsClient client) async {
  print('\n=== Creating KV Bucket ===');

  // Create KV manager
  final kvm = await measureOp('kvm.fromClient', () async => await Kvm.fromClient(client));

  // Create a bucket with options
  final kv = await measureOp('kvm.create bucket', () async {
    return await kvm.create(
      'my-bucket',
      KvOptions(
      description: 'Example KV bucket',
      history: 5, // Keep last 5 values
      storage: StorageType.file,
      replicas: 1,
      ),
    );
  });

  print('Created bucket: ${kv.bucket}');

  // Get bucket status
  final status = await measureOp('kv.status', () async => await kv.status());
  print('Bucket status:');
  print('  Values: ${status.values}');
  print('  Bytes: ${status.bytes}');
  print('  History: ${status.history}');
  print('  Storage: ${status.storage}');

  // List all buckets
  print('\nListing all buckets:');
  await measureOp('kvm.list buckets', () async {
    await for (final bucketName in kvm.list()) {
      print('  - $bucketName');
    }
    return Future.value(null);
  });
}

/// Example 2: Put and Get Operations
Future<void> putGetExample(NatsClient client) async {
  print('\n=== Put and Get Operations ===');

  final kvm = await Kvm.fromClient(client);
  final kv = await kvm.open('my-bucket');

  // Put a string value
  print('\nPutting string value...');
  final rev1 = await measureOp('kv.putString user.name', () async => await kv.putString('user.name', 'John Doe'));
  print('Put user.name with revision: $rev1');

  // Put binary data
  final data = Uint8List.fromList([1, 2, 3, 4, 5]);
  final rev2 = await measureOp('kv.put user.data', () async => await kv.put('user.data', data));
  print('Put user.data with revision: $rev2');

  // Get values
  print('\nGetting values...');
  final nameEntry = await measureOp('kv.get user.name', () async => await kv.get('user.name'));
  if (nameEntry != null) {
    print('user.name = ${nameEntry.string()}');
    print('  Revision: ${nameEntry.revision}');
    print('  Created: ${nameEntry.created}');
    print('  Operation: ${kvOperationToString(nameEntry.operation)}');
  }

  final dataEntry = await measureOp('kv.get user.data', () async => await kv.get('user.data'));
  if (dataEntry != null) {
    print('user.data = ${dataEntry.value}');
    print('  Length: ${dataEntry.length} bytes');
  }

  // Put with structure (JSON)
  await measureOp('kv.putString user.profile', () async {
    return await kv.putString(
      'user.profile',
      '{"age": 30, "city": "San Francisco"}',
    );
  });

  final profileEntry = await measureOp('kv.get user.profile', () async => await kv.get('user.profile'));
  if (profileEntry != null) {
    print('\nuser.profile (as JSON):');
    final profile = profileEntry.json<Map<String, dynamic>>();
    print('  Age: ${profile['age']}');
    print('  City: ${profile['city']}');
  }
}

/// Example 3: Delete and Purge
Future<void> deleteExample(NatsClient client) async {
  print('\n=== Delete and Purge Operations ===');

  final kvm = await Kvm.fromClient(client);
  final kv = await kvm.open('my-bucket');

  // Put a value
  await measureOp('kv.putString temp.key', () async => await kv.putString('temp.key', 'temporary value'));
  print('Created temp.key');

  // Get it
  var entry = await measureOp('kv.get temp.key', () async => await kv.get('temp.key'));
  print('temp.key = ${entry?.string()}');

  // Delete the key
  await measureOp('kv.delete temp.key', () async => await kv.delete('temp.key'));
  print('Deleted temp.key');

  // Try to get deleted key
  entry = await measureOp('kv.get temp.key after delete', () async => await kv.get('temp.key'));
  if (entry != null && entry.isDeleted) {
    print('Key is marked as deleted');
  }

  // Purge removes all history
  await measureOp('kv.purge temp.key', () async => await kv.purge('temp.key'));
  print('Purged temp.key (removed all history)');
}

/// Example 4: List Keys
Future<void> listKeysExample(NatsClient client) async {
  print('\n=== Listing Keys ===');

  final kvm = await Kvm.fromClient(client);
  final kv = await kvm.open('my-bucket');

  // Add some keys
  await measureOp('kv.putString app.config.timeout', () async => await kv.putString('app.config.timeout', '30'));
  await measureOp('kv.putString app.config.retries', () async => await kv.putString('app.config.retries', '3'));
  await measureOp('kv.putString app.feature.flag1', () async => await kv.putString('app.feature.flag1', 'true'));
  await measureOp('kv.putString app.feature.flag2', () async => await kv.putString('app.feature.flag2', 'false'));

  // List all keys
  print('\nAll keys in bucket:');
  await measureOp('kv.keys iteration', () async {
    await for (final key in kv.keys()) {
    final entry = await kv.get(key);
    if (entry != null && !entry.isDeleted) {
      print('  $key = ${entry.string()}');
    }
  }
    return Future.value(null);
  });
}
