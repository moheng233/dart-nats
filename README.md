# Deprecated



# Dart-NATS 
A Dart client for the [NATS](https://nats.io) messaging system. Design to use with Dart and flutter.

### Flutter Web Support by WebSocket 
```dart
client.connect(Uri.parse('ws://localhost:80'));
client.connect(Uri.parse('wss://localhost:443'));
```


### Flutter Other Platform Support both TCP Socket and WebSocket
```dart
client.connect(Uri.parse('nats://localhost:4222'));
client.connect(Uri.parse('tls://localhost:4222'));
client.connect(Uri.parse('ws://localhost:80'));
client.connect(Uri.parse('wss://localhost:443'));
```

### background retry 
```dart
  // unawait 
   client.connect(Uri.parse('nats://localhost:4222'), retry: true, retryCount: -1);
  
  // await for connect if need
   await client.wait4Connected();

   // listen to status stream
   client.statusStream.lesten((status){
    // 
    print(status);
   });
```

### Turn off retry and catch exception
```dart
try {
  await client.connect(Uri.parse('nats://localhost:1234'), retry: false);
} on NatsException {
  //Error handle
}
```

## Dart Examples:

Run the `example/main.dart`:

```
dart example/main.dart
```

```dart
import 'package:dart_nats/dart_nats.dart';

void main() async {
  var client = Client();
  client.connect(Uri.parse('nats://localhost'));
  var sub = client.sub('subject1');
  await client.pubString('subject1', 'message1');
  var msg = await sub.stream.first;

  print(msg.string);
  client.unSub(sub);
  client.close();
}
```

## Flutter Examples:

Import and Declare object
```dart
import 'package:dart_nats/dart_nats.dart' as nats;

nats.Client natsClient;
nats.Subscription fooSub, barSub;
```

Simply connect to server and subscribe to subject
```dart
void connect() {
  natsClient = nats.Client();
  natsClient.connect(Uri.parse('nats://hostname');
  fooSub = natsClient.sub('foo');
  barSub = natsClient.sub('bar');
}
```
Use as Stream in StreamBuilder
```dart
StreamBuilder(
  stream: fooSub.stream,
  builder: (context, AsyncSnapshot<nats.Message> snapshot) {
    return Text(snapshot.hasData ? '${snapshot.data.string}' : '');
  },
),
```

Publish Message
```dart
      await natsClient.pubString('subject','message string');
```

Request 
```dart
var client = Client();
client.inboxPrefix = '_INBOX.test_test';
await client.connect(Uri.parse('nats://localhost:4222'));
var receive = await client.request(
    'service', Uint8List.fromList('request'.codeUnits));
```

Structure Request 
```dart
var client = Client();
await client.connect(Uri.parse('nats://localhost:4222'));
client.registerJsonDecoder<Student>(json2Student);
var receive = await client.requestString<Student>('service', '');
var student = receive.data;


Student json2Student(String json) {
  return Student.fromJson(jsonDecode(json));
}
```

Dispose 
```dart
  void dispose() {
    natsClient.close();
    super.dispose();
  }
```

## Authentication

Token Authtication 
```dart
var client = Client();
client.connect(Uri.parse('nats://localhost'),
          connectOption: ConnectOption(authToken: 'mytoken'));
```

User/Passwore Authentication
```dart
var client = Client();
client.connect(Uri.parse('nats://localhost'),
          connectOption: ConnectOption(user: 'foo', pass: 'bar'));
```

NKEY Authentication
```dart
var client = Client();
client.seed =
    'SUACSSL3UAHUDXKFSNVUZRF5UHPMWZ6BFDTJ7M6USDXIEDNPPQYYYCU3VY';
client.connect(
  Uri.parse('nats://localhost'),
  connectOption: ConnectOption(
    nkey: 'UDXU4RCSJNZOIQHZNWXHXORDPRTGNJAHAHFRGZNEEJCPQTT2M7NLCNF4',
  ),
);
```

JWT Authentication
```dart
var client = Client();
client.seed =
    'SUAJGSBAKQHGYI7ZVKVR6WA7Z5U52URHKGGT6ZICUJXMG4LCTC2NTLQSF4';
client.connect(
  Uri.parse('nats://localhost'),
  connectOption: ConnectOption(
    jwt:
        '''eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJqdGkiOiJBU1pFQVNGMzdKS0dPTFZLTFdKT1hOM0xZUkpHNURJUFczUEpVT0s0WUlDNFFENlAyVFlRIiwiaWF0IjoxNjY0NTI0OTU5LCJpc3MiOiJBQUdTSkVXUlFTWFRDRkUzRVE3RzVPQldSVUhaVVlDSFdSM0dRVERGRldaSlM1Q1JLTUhOTjY3SyIsIm5hbWUiOiJzaWdudXAiLCJzdWIiOiJVQzZCUVY1Tlo1V0pQRUVZTTU0UkZBNU1VMk5NM0tON09WR01DU1VaV1dORUdZQVBNWEM0V0xZUCIsIm5hdHMiOnsicHViIjp7fSwic3ViIjp7fSwic3VicyI6LTEsImRhdGEiOi0xLCJwYXlsb2FkIjotMSwidHlwZSI6InVzZXIiLCJ2ZXJzaW9uIjoyfX0.8Q0HiN0h2tBvgpF2cAaz2E3WLPReKEnSmUWT43NSlXFNRpsCWpmkikxGgFn86JskEN4yast1uSj306JdOhyJBA''',
  ),
);
```




Full Flutter sample code [example/flutter/main.dart](https://github.com/chartchuo/dart-nats/blob/master/example/flutter/main_dart)


## Features
The following is a list of features currently supported: 

- [x] - Publish
- [x] - Subscribe, unsubscribe
- [x] - NUID, Inbox
- [x] - Reconnect to single server when connection lost and resume subscription
- [x] - Unsubscribe after N message
- [x] - Request, Respond
- [x] - Queue subscribe
- [x] - Request timeout
- [x] - Events/status 
- [x] - Buffering message during reconnect atempts
- [x] - All authentication models, including NATS 2.0 JWT and nkey
- [x] - NATS 2.x 
- [x] - TLS 
- [x] - JetStream support

Planned:
- [ ] - Connect to list of servers

## JetStream

JetStream is the NATS persistence engine providing streaming, message, and worker queues with At-Least-Once semantics.

### Stream Management

```dart
import 'package:dart_nats/dart_nats.dart';

// Create JetStream manager
var client = Client();
await client.connect(Uri.parse('nats://localhost:4222'));
final jsm = await jetstreamManager(client);

// Create a stream
final streamConfig = StreamConfig(
  name: 'ORDERS',
  subjects: ['orders.>'],
  retention: RetentionPolicy.limits,
  maxMsgs: 1000,
  storage: StorageType.file,
);
final streamInfo = await jsm.addStream(streamConfig);

// List streams
await for (final streamName in jsm.listStreams()) {
  print('Stream: $streamName');
}

// Get stream info
final info = await jsm.getStreamInfo('ORDERS');
print('Messages: ${info.state.messages}');
```

### Publishing with JetStream

```dart
// Create JetStream client
final js = jetstream(client);

// Publish a message and get acknowledgment
final pubAck = await js.publishString(
  'orders.new',
  '{"id": "123", "item": "widget"}',
  options: JetStreamPublishOptions(
    msgId: 'order-123',
    headers: {'order-id': '123'},
  ),
);

print('Published to stream: ${pubAck.stream}');
print('Sequence: ${pubAck.seq}');
```

### Pull Consumer

```dart
// Create a durable pull consumer
final consumerConfig = ConsumerConfig(
  durableName: 'ORDERS_PROCESSOR',
  filterSubject: 'orders.>',
  ackPolicy: AckPolicy.explicit,
);
await jsm.addConsumer('ORDERS', consumerConfig);

// Subscribe and fetch messages
final sub = await js.pullSubscribe(
  'orders.>',
  stream: 'ORDERS',
  consumer: 'ORDERS_PROCESSOR',
);

await for (final msg in sub.fetch(10)) {
  print('Received: ${msg.stringData}');
  print('Stream sequence: ${msg.deliveredStreamSeq}');
  
  // Acknowledge the message
  msg.ack();
}
```

### Push Consumer

```dart
// Subscribe to a push consumer
final stream = await js.pushSubscribe(
  'orders.shipped',
  stream: 'ORDERS',
);

await for (final msg in stream) {
  print('Received: ${msg.stringData}');
  msg.ack();
}
```

### Consumer Management

```dart
// Create consumer
final consumer = ConsumerConfig(
  durableName: 'MY_CONSUMER',
  filterSubject: 'events.>',
  ackPolicy: AckPolicy.explicit,
  deliverPolicy: DeliverPolicy.all,
);
await jsm.addConsumer('MY_STREAM', consumer);

// List consumers
await for (final consumerName in jsm.listConsumers('MY_STREAM')) {
  print('Consumer: $consumerName');
}

// Get consumer info
final consumerInfo = await jsm.getConsumerInfo('MY_STREAM', 'MY_CONSUMER');
print('Pending: ${consumerInfo.numPending}');

// Delete consumer
await jsm.deleteConsumer('MY_STREAM', 'MY_CONSUMER');
```

For complete examples, see [example/jetstream_example.dart](example/jetstream_example.dart).

## KV (Key-Value) Store

KV is a key-value store built on top of JetStream, providing a simple interface for storing and retrieving values by key.

### Creating a KV Bucket

```dart
import 'package:dart_nats/dart_nats.dart';

// Create KV manager
var client = Client();
await client.connect(Uri.parse('nats://localhost:4222'));
final kvm = await Kvm.fromClient(client);

// Create a bucket
final kv = await kvm.create('my-bucket', KvOptions(
  description: 'My KV bucket',
  history: 5,  // Keep last 5 values
  storage: StorageType.file,
));
```

### Put and Get Operations

```dart
// Put a string value
final revision = await kv.putString('user.name', 'John Doe');

// Get the value
final entry = await kv.get('user.name');
if (entry != null) {
  print('Value: ${entry.string()}');
  print('Revision: ${entry.revision}');
}

// Put binary data
await kv.put('user.avatar', avatarBytes);

// Store JSON
await kv.putString('user.profile', '{"age": 30, "city": "SF"}');
final profileEntry = await kv.get('user.profile');
final profile = profileEntry?.json<Map<String, dynamic>>();
```

### Delete and Purge

```dart
// Delete a key (marks as deleted, keeps in history)
await kv.delete('user.name');

// Purge a key (removes all history)
await kv.purge('user.name');
```

### Listing Keys

```dart
// List all keys in the bucket
await for (final key in kv.keys()) {
  final entry = await kv.get(key);
  if (entry != null && !entry.isDeleted) {
    print('$key = ${entry.string()}');
  }
}
```

For complete examples, see [example/kv_example.dart](example/kv_example.dart).

## Object Store

Object Store provides efficient storage for large objects with automatic chunking.

### Creating an Object Store

```dart
import 'package:dart_nats/dart_nats.dart';

// Create Object Store manager
var client = Client();
await client.connect(Uri.parse('nats://localhost:4222'));
final objm = await Objm.fromClient(client);

// Create a store
final store = await objm.create('my-store', ObjectStoreOptions(
  description: 'My object store',
  storage: StorageType.file,
));
```

### Storing Objects

```dart
// Put a small object
final textData = Uint8List.fromList(utf8.encode('Hello, World!'));
final info = await store.put(
  ObjectStoreMeta(
    name: 'greeting.txt',
    description: 'A greeting',
    metadata: {'type': 'text'},
  ),
  textData,
);

print('Stored: ${info.name}, Size: ${info.size}, Chunks: ${info.chunks}');

// Put a large object (automatically chunked)
final largeData = Uint8List(1024 * 1024); // 1 MB
await store.put(
  ObjectStoreMeta(
    name: 'large-file.bin',
    options: ObjectStoreMetaOptions(
      maxChunkSize: 128 * 1024, // 128 KB chunks
    ),
  ),
  largeData,
);
```

### Retrieving Objects

```dart
// Get an object
final data = await store.get('greeting.txt');
if (data != null) {
  print('Retrieved: ${utf8.decode(data)}');
}

// Get object info without data
final info = await store.getInfo('greeting.txt');
print('Size: ${info?.size} bytes');
```

### Listing and Deleting Objects

```dart
// List all objects
await for (final name in store.list()) {
  print('Object: $name');
}

// Delete an object
await store.delete('greeting.txt');
```

For complete examples, see [example/objectstore_example.dart](example/objectstore_example.dart).
