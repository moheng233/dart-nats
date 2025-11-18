import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_nats/dart_nats.dart';

/// Example demonstrating Object Store functionality
///
/// This example shows how to:
/// 1. Create and manage object stores
/// 2. Put and get objects (including large ones with chunking)
/// 3. Delete objects
/// 4. List objects in a store
/// 5. Get store status
///
/// Prerequisites:
/// - NATS server with JetStream enabled
/// - Run: docker-compose up -d (from repository root)
///
/// Run this example:
/// dart example/objectstore_example.dart

void main() async {
  // Create a NATS client
  var client = NatsClient();

  try {
    // Connect to NATS server
    print('Connecting to NATS server...');
    await client.connect(Uri.parse('nats://localhost:4222'));
    print('Connected to NATS server');

    // Wait for connection
    await client.waitUntilConnected();

    // Example 1: Create Object Store
    await createStoreExample(client);

    // Example 2: Put and Get Objects
    await putGetExample(client);

    // Example 3: Large Object with Chunking
    await largeObjectExample(client);

    // Example 4: List Objects
    await listObjectsExample(client);

    // Example 5: Delete Objects
    await deleteExample(client);

    print('\n✓ All Object Store examples completed successfully!');
  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
    print('\nConnection closed');
  }
}

/// Example 1: Create Object Store
Future<void> createStoreExample(NatsClient client) async {
  print('\n=== Creating Object Store ===');

  // Create Object Store manager
  final objm = await Objm.fromClient(client);

  // Create a store with options
  final store = await objm.create(
    'my-store',
    ObjectStoreOptions(
      description: 'Example object store',
      storage: StorageType.file,
      replicas: 1,
    ),
  );

  print('Created store: ${store.bucket}');

  // Get store status
  final status = await store.status();
  print('Store status:');
  print('  Size: ${status.size} bytes');
  print('  Storage: ${status.storage}');
  print('  Replicas: ${status.replicas}');

  // List all stores
  print('\nListing all object stores:');
  await for (final storeName in objm.list()) {
    print('  - $storeName');
  }
}

/// Example 2: Put and Get Objects
Future<void> putGetExample(NatsClient client) async {
  print('\n=== Put and Get Objects ===');

  final objm = await Objm.fromClient(client);
  final store = await objm.open('my-store');

  // Put a small text object
  print('\nPutting text object...');
  final textData = Uint8List.fromList(utf8.encode('Hello, Object Store!'));
  final textMeta = ObjectStoreMeta(
    name: 'greeting.txt',
    description: 'A simple greeting',
    metadata: {
      'type': 'text',
      'encoding': 'utf-8',
    },
  );

  final info = await store.put(textMeta, textData);
  print('Put ${info.name}:');
  print('  Size: ${info.size} bytes');
  print('  Chunks: ${info.chunks}');
  print('  Digest: ${info.digest}');

  // Get the object back
  print('\nGetting object...');
  final retrieved = await store.get('greeting.txt');
  if (retrieved != null) {
    print('Retrieved: ${utf8.decode(retrieved)}');
  }

  // Put a JSON object
  final jsonData = Uint8List.fromList(utf8.encode(jsonEncode({
    'name': 'John Doe',
    'age': 30,
    'email': 'john@example.com',
  })));

  await store.put(
    ObjectStoreMeta(
      name: 'user.json',
      description: 'User profile data',
    ),
    jsonData,
  );
  print('\nPut user.json');
}

/// Example 3: Large Object with Chunking
Future<void> largeObjectExample(NatsClient client) async {
  print('\n=== Large Object with Chunking ===');

  final objm = await Objm.fromClient(client);
  final store = await objm.open('my-store');

  // Create a large object (300 KB) - will be split into chunks
  final largeSize = 300 * 1024; // 300 KB
  final largeData = Uint8List(largeSize);
  for (var i = 0; i < largeSize; i++) {
    largeData[i] = i % 256;
  }

  print('Putting large object ($largeSize bytes)...');
  final meta = ObjectStoreMeta(
    name: 'large-file.bin',
    description: 'A large binary file',
    options: ObjectStoreMetaOptions(
      maxChunkSize: 128 * 1024, // 128 KB chunks
    ),
  );

  final info = await store.put(meta, largeData);
  print('Put ${info.name}:');
  print('  Size: ${info.size} bytes');
  print('  Chunks: ${info.chunks}');
  print('  Digest: ${info.digest}');

  // Retrieve the large object
  print('\nRetrieving large object...');
  final retrieved = await store.get('large-file.bin');
  if (retrieved != null) {
    print('Retrieved ${retrieved.length} bytes');
    
    // Verify the data
    var matches = true;
    for (var i = 0; i < largeSize && matches; i++) {
      if (retrieved[i] != largeData[i]) {
        matches = false;
      }
    }
    print('Data integrity check: ${matches ? "✓ PASSED" : "✗ FAILED"}');
  }
}

/// Example 4: List Objects
Future<void> listObjectsExample(NatsClient client) async {
  print('\n=== Listing Objects ===');

  final objm = await Objm.fromClient(client);
  final store = await objm.open('my-store');

  // Add a few more objects
  await store.put(
    ObjectStoreMeta(name: 'doc1.txt'),
    Uint8List.fromList(utf8.encode('Document 1')),
  );
  await store.put(
    ObjectStoreMeta(name: 'doc2.txt'),
    Uint8List.fromList(utf8.encode('Document 2')),
  );
  await store.put(
    ObjectStoreMeta(name: 'image.png'),
    Uint8List.fromList([137, 80, 78, 71]), // PNG header
  );

  // List all objects
  print('\nAll objects in store:');
  await for (final name in store.list()) {
    final info = await store.getInfo(name);
    if (info != null) {
      print('  $name - ${info.size} bytes (${info.chunks} chunks)');
    }
  }
}

/// Example 5: Delete Objects
Future<void> deleteExample(NatsClient client) async {
  print('\n=== Delete Objects ===');

  final objm = await Objm.fromClient(client);
  final store = await objm.open('my-store');

  // Put a temporary object
  await store.put(
    ObjectStoreMeta(name: 'temp.dat'),
    Uint8List.fromList([1, 2, 3, 4, 5]),
  );
  print('Created temp.dat');

  // Get it
  var data = await store.get('temp.dat');
  print('Retrieved temp.dat: ${data?.length} bytes');

  // Delete it
  await store.delete('temp.dat');
  print('Deleted temp.dat');

  // Try to get deleted object
  data = await store.get('temp.dat');
  print('After deletion: ${data == null ? "null (deleted)" : "still exists"}');
}
