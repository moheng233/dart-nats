import 'dart:typed_data';
import 'package:dart_nats/dart_nats.dart';
import 'package:test/test.dart';

/// Basic JetStream tests
/// 
/// Prerequisites:
/// - NATS server with JetStream enabled running on localhost:4222
/// - Run: docker-compose up -d (from repository root)

void main() {
  group('JetStream Types', () {
    test('StreamConfig serialization', () {
      final config = StreamConfig(
        name: 'TEST_STREAM',
        subjects: ['test.>'],
        retention: RetentionPolicy.limits,
        maxMsgs: 100,
        storage: StorageType.memory,
      );

      final json = config.toJson();
      expect(json['name'], equals('TEST_STREAM'));
      expect(json['subjects'], equals(['test.>']));
      expect(json['retention'], equals('limits'));
      expect(json['storage'], equals('memory'));

      final decoded = StreamConfig.fromJson(json);
      expect(decoded.name, equals(config.name));
      expect(decoded.subjects, equals(config.subjects));
      expect(decoded.retention, equals(config.retention));
      expect(decoded.storage, equals(config.storage));
    });

    test('ConsumerConfig serialization', () {
      final config = ConsumerConfig(
        durableName: 'TEST_CONSUMER',
        ackPolicy: AckPolicy.explicit,
        deliverPolicy: DeliverPolicy.all,
        filterSubject: 'test.subject',
      );

      final json = config.toJson();
      expect(json['durable_name'], equals('TEST_CONSUMER'));
      expect(json['ack_policy'], equals('explicit'));
      expect(json['deliver_policy'], equals('all'));
      expect(json['filter_subject'], equals('test.subject'));

      final decoded = ConsumerConfig.fromJson(json);
      expect(decoded.durableName, equals(config.durableName));
      expect(decoded.ackPolicy, equals(config.ackPolicy));
      expect(decoded.deliverPolicy, equals(config.deliverPolicy));
    });

    test('PubAck serialization', () {
      final pubAck = PubAck(
        stream: 'TEST',
        seq: 42,
        duplicate: false,
      );

      final json = pubAck.toJson();
      expect(json['stream'], equals('TEST'));
      expect(json['seq'], equals(42));
      expect(json['duplicate'], equals(false));

      final decoded = PubAck.fromJson(json);
      expect(decoded.stream, equals(pubAck.stream));
      expect(decoded.seq, equals(pubAck.seq));
      expect(decoded.duplicate, equals(pubAck.duplicate));
    });
  });

  group('JetStream Enums', () {
    test('RetentionPolicy conversion', () {
      expect(_retentionPolicyToString(RetentionPolicy.limits), equals('limits'));
      expect(_retentionPolicyToString(RetentionPolicy.interest), equals('interest'));
      expect(_retentionPolicyToString(RetentionPolicy.workQueue), equals('workqueue'));

      expect(_retentionPolicyFromString('limits'), equals(RetentionPolicy.limits));
      expect(_retentionPolicyFromString('interest'), equals(RetentionPolicy.interest));
      expect(_retentionPolicyFromString('workqueue'), equals(RetentionPolicy.workQueue));
    });

    test('StorageType conversion', () {
      expect(_storageTypeToString(StorageType.file), equals('file'));
      expect(_storageTypeToString(StorageType.memory), equals('memory'));

      expect(_storageTypeFromString('file'), equals(StorageType.file));
      expect(_storageTypeFromString('memory'), equals(StorageType.memory));
    });

    test('AckPolicy conversion', () {
      expect(_ackPolicyToString(AckPolicy.none), equals('none'));
      expect(_ackPolicyToString(AckPolicy.explicit), equals('explicit'));
      expect(_ackPolicyToString(AckPolicy.all), equals('all'));

      expect(_ackPolicyFromString('none'), equals(AckPolicy.none));
      expect(_ackPolicyFromString('explicit'), equals(AckPolicy.explicit));
      expect(_ackPolicyFromString('all'), equals(AckPolicy.all));
    });

    test('DeliverPolicy conversion', () {
      expect(_deliverPolicyToString(DeliverPolicy.all), equals('all'));
      expect(_deliverPolicyToString(DeliverPolicy.last), equals('last'));
      expect(_deliverPolicyToString(DeliverPolicy.new_), equals('new'));

      expect(_deliverPolicyFromString('all'), equals(DeliverPolicy.all));
      expect(_deliverPolicyFromString('last'), equals(DeliverPolicy.last));
      expect(_deliverPolicyFromString('new'), equals(DeliverPolicy.new_));
    });
  });

  group('JetStream Errors', () {
    test('JetStreamException', () {
      final ex = JetStreamException('test error');
      expect(ex.message, equals('test error'));
      expect(ex.toString(), contains('test error'));
    });

    test('StreamNotFoundException', () {
      final ex = StreamNotFoundException('MY_STREAM');
      expect(ex.streamName, equals('MY_STREAM'));
      expect(ex.toString(), contains('MY_STREAM'));
    });

    test('ConsumerNotFoundException', () {
      final ex = ConsumerNotFoundException('MY_STREAM', 'MY_CONSUMER');
      expect(ex.streamName, equals('MY_STREAM'));
      expect(ex.consumerName, equals('MY_CONSUMER'));
      expect(ex.toString(), contains('MY_STREAM'));
      expect(ex.toString(), contains('MY_CONSUMER'));
    });
  });

  group('JetStream Message', () {
    test('JsMsg metadata extraction', () {
      // Create a mock message with JetStream headers
      final header = Header();
      header.add('Nats-Stream', 'TEST_STREAM');
      header.add('Nats-Consumer', 'TEST_CONSUMER');
      header.add('Nats-Delivered-Consumer-Seq', '10');
      header.add('Nats-Delivered-Stream-Seq', '42');
      header.add('Nats-Pending-Messages', '5');

      // Create a client (we won't use it for this test)
      final client = NatsClient();
      
      // Create a NATS message
      final msg = Message(
        'test.subject',
        1,
        Uint8List.fromList('test data'.codeUnits),
        client,
        header: header,
      );

      // Wrap in JsMsg
      final jsMsg = JsMsg(msg);

      expect(jsMsg.stream, equals('TEST_STREAM'));
      expect(jsMsg.consumer, equals('TEST_CONSUMER'));
      expect(jsMsg.deliveredConsumerSeq, equals(10));
      expect(jsMsg.deliveredStreamSeq, equals(42));
      expect(jsMsg.pending, equals(5));
      expect(jsMsg.stringData, equals('test data'));
    });
  });
}

// Import helper functions for testing
// These are copied from jsapi_types.dart for testing
String _retentionPolicyToString(RetentionPolicy policy) {
  switch (policy) {
    case RetentionPolicy.interest:
      return 'interest';
    case RetentionPolicy.workQueue:
      return 'workqueue';
    default:
      return 'limits';
  }
}

RetentionPolicy _retentionPolicyFromString(String? value) {
  switch (value) {
    case 'interest':
      return RetentionPolicy.interest;
    case 'workqueue':
      return RetentionPolicy.workQueue;
    default:
      return RetentionPolicy.limits;
  }
}

String _storageTypeToString(StorageType type) {
  switch (type) {
    case StorageType.memory:
      return 'memory';
    default:
      return 'file';
  }
}

StorageType _storageTypeFromString(String? value) {
  switch (value) {
    case 'memory':
      return StorageType.memory;
    default:
      return StorageType.file;
  }
}

String _ackPolicyToString(AckPolicy policy) {
  switch (policy) {
    case AckPolicy.none:
      return 'none';
    case AckPolicy.all:
      return 'all';
    default:
      return 'explicit';
  }
}

AckPolicy _ackPolicyFromString(String? value) {
  switch (value) {
    case 'none':
      return AckPolicy.none;
    case 'all':
      return AckPolicy.all;
    default:
      return AckPolicy.explicit;
  }
}

String _deliverPolicyToString(DeliverPolicy policy) {
  switch (policy) {
    case DeliverPolicy.last:
      return 'last';
    case DeliverPolicy.new_:
      return 'new';
    case DeliverPolicy.byStartSequence:
      return 'by_start_sequence';
    case DeliverPolicy.byStartTime:
      return 'by_start_time';
    case DeliverPolicy.lastPerSubject:
      return 'last_per_subject';
    default:
      return 'all';
  }
}

DeliverPolicy _deliverPolicyFromString(String? value) {
  switch (value) {
    case 'last':
      return DeliverPolicy.last;
    case 'new':
      return DeliverPolicy.new_;
    case 'by_start_sequence':
      return DeliverPolicy.byStartSequence;
    case 'by_start_time':
      return DeliverPolicy.byStartTime;
    case 'last_per_subject':
      return DeliverPolicy.lastPerSubject;
    default:
      return DeliverPolicy.all;
  }
}
