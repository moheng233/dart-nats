import 'dart:async';
import 'dart:typed_data';
import 'package:dart_nats/dart_nats.dart';

/// Example demonstrating JetStream functionality
/// 
/// This example shows how to:
/// 1. Create a JetStream manager
/// 2. Create and manage streams
/// 3. Create and manage consumers
/// 4. Publish messages with JetStream acknowledgments
/// 5. Subscribe to messages using pull and push consumers
/// 6. Acknowledge messages
///
/// Prerequisites:
/// - NATS server with JetStream enabled
/// - Run: docker-compose up -d (from repository root)
/// 
/// Run this example:
/// dart example/jetstream_example.dart

void main() async {
  // Create a NATS client
  var client = Client();
  
  try {
    // Connect to NATS server
    print('Connecting to NATS server...');
    await client.connect(Uri.parse('nats://localhost:4222'));
    print('Connected to NATS server');

    // Wait for connection to be established
    await client.wait4Connected();

    // Example 1: Stream Management
    await streamManagementExample(client);

    // Example 2: Publishing with JetStream
    await publishExample(client);

    // Example 3: Pull Consumer
    await pullConsumerExample(client);

    // Example 4: Push Consumer
    await pushConsumerExample(client);

    print('\n✓ All examples completed successfully!');
  } catch (e) {
    print('Error: $e');
  } finally {
    // Clean up
    client.close();
    print('\nConnection closed');
  }
}

/// Example 1: Stream Management
Future<void> streamManagementExample(Client client) async {
  print('\n=== Stream Management Example ===');

  // Create a JetStream manager
  print('Creating JetStream manager...');
  final jsm = await jetstreamManager(client);
  print('JetStream manager created');

  // Get account info
  try {
    final accountInfo = await jsm.getAccountInfo();
    print('Account info: ${accountInfo.streams} streams, ${accountInfo.consumers} consumers');
  } catch (e) {
    print('Could not get account info (JetStream might not be enabled): $e');
  }

  // Create a stream
  print('\nCreating stream "ORDERS"...');
  final streamConfig = StreamConfig(
    name: 'ORDERS',
    subjects: ['orders.>'],
    retention: RetentionPolicy.limits,
    maxMsgs: 1000,
    maxBytes: 1024 * 1024, // 1MB
    maxAge: 3600 * 1000000000, // 1 hour in nanoseconds
    storage: StorageType.file,
    numReplicas: 1,
    description: 'Orders stream example',
  );

  try {
    final streamInfo = await jsm.addStream(streamConfig);
    print('Stream created: ${streamInfo.config.name}');
    print('  Subjects: ${streamInfo.config.subjects}');
    print('  Storage: ${streamInfo.config.storage}');
  } on StreamAlreadyExistsException {
    print('Stream already exists, updating...');
    final streamInfo = await jsm.updateStream(streamConfig);
    print('Stream updated: ${streamInfo.config.name}');
  } catch (e) {
    print('Error creating stream: $e');
  }

  // List streams
  print('\nListing all streams:');
  await for (final streamName in jsm.listStreams()) {
    print('  - $streamName');
  }

  // Get stream info
  try {
    final streamInfo = await jsm.getStreamInfo('ORDERS');
    print('\nStream info for ORDERS:');
    print('  Messages: ${streamInfo.state.messages}');
    print('  Bytes: ${streamInfo.state.bytes}');
    print('  First seq: ${streamInfo.state.firstSeq}');
    print('  Last seq: ${streamInfo.state.lastSeq}');
  } catch (e) {
    print('Error getting stream info: $e');
  }
}

/// Example 2: Publishing with JetStream
Future<void> publishExample(Client client) async {
  print('\n=== Publishing Example ===');

  // Create a JetStream client
  final js = jetstream(client);

  // Publish a message
  print('Publishing message to orders.new...');
  final pubAck = await js.publishString(
    'orders.new',
    '{"id": "123", "item": "widget", "quantity": 10}',
    options: JetStreamPublishOptions(
      msgId: 'order-123',
      headers: {
        'order-id': '123',
        'timestamp': DateTime.now().toIso8601String(),
      },
    ),
  );

  print('Message published!');
  print('  Stream: ${pubAck.stream}');
  print('  Sequence: ${pubAck.seq}');
  print('  Duplicate: ${pubAck.duplicate}');

  // Publish multiple messages
  print('\nPublishing batch of messages...');
  for (var i = 1; i <= 5; i++) {
    final ack = await js.publishString(
      'orders.processed',
      '{"id": "$i", "status": "processed"}',
    );
    print('  Message $i published with sequence ${ack.seq}');
  }
}

/// Example 3: Pull Consumer
Future<void> pullConsumerExample(Client client) async {
  print('\n=== Pull Consumer Example ===');

  final jsm = await jetstreamManager(client);
  final js = jetstream(client);

  // Create a durable pull consumer
  print('Creating pull consumer...');
  final consumerConfig = ConsumerConfig(
    durableName: 'ORDERS_PROCESSOR',
    filterSubject: 'orders.>',
    ackPolicy: AckPolicy.explicit,
    deliverPolicy: DeliverPolicy.all,
    maxAckPending: 100,
  );

  try {
    await jsm.addConsumer('ORDERS', consumerConfig);
    print('Consumer created: ORDERS_PROCESSOR');
  } on ConsumerAlreadyExistsException {
    print('Consumer already exists');
  } catch (e) {
    print('Error creating consumer: $e');
    return;
  }

  // Subscribe to the consumer
  print('\nFetching messages from pull consumer...');
  final sub = await js.pullSubscribe(
    'orders.>',
    stream: 'ORDERS',
    consumer: 'ORDERS_PROCESSOR',
  );

  // Fetch messages
  var msgCount = 0;
  await for (final jsMsg in sub.fetch(5)) {
    msgCount++;
    print('\nReceived message $msgCount:');
    print('  Subject: ${jsMsg.subject}');
    print('  Data: ${jsMsg.stringData}');
    print('  Stream: ${jsMsg.stream}');
    print('  Consumer seq: ${jsMsg.deliveredConsumerSeq}');
    print('  Stream seq: ${jsMsg.deliveredStreamSeq}');

    // Acknowledge the message
    jsMsg.ack();
    print('  ✓ Acknowledged');

    if (msgCount >= 5) break;
  }

  print('\nProcessed $msgCount messages');
}

/// Example 4: Push Consumer
Future<void> pushConsumerExample(Client client) async {
  print('\n=== Push Consumer Example ===');

  final jsm = await jetstreamManager(client);
  final js = jetstream(client);

  // Publish some test messages first
  print('Publishing test messages...');
  for (var i = 1; i <= 3; i++) {
    await js.publishString(
      'orders.shipped',
      '{"id": "$i", "status": "shipped"}',
    );
  }

  // Create a push consumer
  print('\nCreating push consumer...');
  final deliverSubject = client.newInbox();
  final consumerConfig = ConsumerConfig(
    deliverSubject: deliverSubject,
    filterSubject: 'orders.shipped',
    ackPolicy: AckPolicy.explicit,
    deliverPolicy: DeliverPolicy.all,
  );

  try {
    await jsm.addConsumer('ORDERS', consumerConfig);
    print('Push consumer created');
  } catch (e) {
    print('Note: Consumer creation may fail - continuing to subscribe anyway');
  }

  // Subscribe to the push consumer
  print('Subscribing to push consumer...');
  final stream = await js.pushSubscribe(
    'orders.shipped',
    stream: 'ORDERS',
    deliverSubject: deliverSubject,
  );

  // Process messages
  print('Waiting for messages...');
  var count = 0;
  final timeout = Timer(Duration(seconds: 3), () {});
  
  await for (final jsMsg in stream) {
    count++;
    print('\nPush message $count:');
    print('  Subject: ${jsMsg.subject}');
    print('  Data: ${jsMsg.stringData}');
    print('  Pending: ${jsMsg.pending}');

    // Acknowledge
    jsMsg.ack();
    print('  ✓ Acknowledged');

    if (count >= 3) break;
  }

  timeout.cancel();
  print('\nProcessed $count push messages');
}
