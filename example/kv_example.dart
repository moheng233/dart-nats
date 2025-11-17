import 'dart:typed_data';
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
  var client = Client();

  try {
    // Connect to NATS server
    print('Connecting to NATS server...');
    await client.connect(Uri.parse('nats://localhost:4222'));
    print('Connected to NATS server');

    // Wait for connection
    await client.waitUntilConnected();

    // Example 1: Create KV Manager and Bucket
    await createBucketExample(client);

    // Example 2: Put and Get Operations
    await putGetExample(client);

    // Example 3: Delete and Purge
    await deleteExample(client);

    // Example 4: List Keys
    await listKeysExample(client);

    print('\n✓ All KV examples completed successfully!');
  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
    print('\nConnection closed');
  }
}

/// Example 1: Create KV Manager and Bucket
Future<void> createBucketExample(Client client) async {
  print('\n=== Creating KV Bucket ===');

  // Create KV manager
  final kvm = await Kvm.fromClient(client);

  // Create a bucket with options
  final kv = await kvm.create(
    'my-bucket',
    KvOptions(
      description: 'Example KV bucket',
      history: 5, // Keep last 5 values
      storage: StorageType.file,
      replicas: 1,
    ),
  );

  print('Created bucket: ${kv.bucket}');

  // Get bucket status
  final status = await kv.status();
  print('Bucket status:');
  print('  Values: ${status.values}');
  print('  Bytes: ${status.bytes}');
  print('  History: ${status.history}');
  print('  Storage: ${status.storage}');

  // List all buckets
  print('\nListing all buckets:');
  await for (final bucketName in kvm.list()) {
    print('  - $bucketName');
  }
}

/// Example 2: Put and Get Operations
Future<void> putGetExample(Client client) async {
  print('\n=== Put and Get Operations ===');

  final kvm = await Kvm.fromClient(client);
  final kv = await kvm.open('my-bucket');

  // Put a string value
  print('\nPutting string value...');
  final rev1 = await kv.putString('user.name', 'John Doe');
  print('Put user.name with revision: $rev1');

  // Put binary data
  final data = Uint8List.fromList([1, 2, 3, 4, 5]);
  final rev2 = await kv.put('user.data', data);
  print('Put user.data with revision: $rev2');

  // Get values
  print('\nGetting values...');
  final nameEntry = await kv.get('user.name');
  if (nameEntry != null) {
    print('user.name = ${nameEntry.string()}');
    print('  Revision: ${nameEntry.revision}');
    print('  Created: ${nameEntry.created}');
    print('  Operation: ${kvOperationToString(nameEntry.operation)}');
  }

  final dataEntry = await kv.get('user.data');
  if (dataEntry != null) {
    print('user.data = ${dataEntry.value}');
    print('  Length: ${dataEntry.length} bytes');
  }

  // Put with structure (JSON)
  await kv.putString(
    'user.profile',
    '{"age": 30, "city": "San Francisco"}',
  );

  final profileEntry = await kv.get('user.profile');
  if (profileEntry != null) {
    print('\nuser.profile (as JSON):');
    final profile = profileEntry.json<Map<String, dynamic>>();
    print('  Age: ${profile['age']}');
    print('  City: ${profile['city']}');
  }
}

/// Example 3: Delete and Purge
Future<void> deleteExample(Client client) async {
  print('\n=== Delete and Purge Operations ===');

  final kvm = await Kvm.fromClient(client);
  final kv = await kvm.open('my-bucket');

  // Put a value
  await kv.putString('temp.key', 'temporary value');
  print('Created temp.key');

  // Get it
  var entry = await kv.get('temp.key');
  print('temp.key = ${entry?.string()}');

  // Delete the key
  await kv.delete('temp.key');
  print('Deleted temp.key');

  // Try to get deleted key
  entry = await kv.get('temp.key');
  if (entry != null && entry.isDeleted) {
    print('Key is marked as deleted');
  }

  // Purge removes all history
  await kv.purge('temp.key');
  print('Purged temp.key (removed all history)');
}

/// Example 4: List Keys
Future<void> listKeysExample(Client client) async {
  print('\n=== Listing Keys ===');

  final kvm = await Kvm.fromClient(client);
  final kv = await kvm.open('my-bucket');

  // Add some keys
  await kv.putString('app.config.timeout', '30');
  await kv.putString('app.config.retries', '3');
  await kv.putString('app.feature.flag1', 'true');
  await kv.putString('app.feature.flag2', 'false');

  // List all keys
  print('\nAll keys in bucket:');
  await for (final key in kv.keys()) {
    final entry = await kv.get(key);
    if (entry != null && !entry.isDeleted) {
      print('  $key = ${entry.string()}');
    }
  }
}
