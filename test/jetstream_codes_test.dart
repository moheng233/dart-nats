import 'package:test/test.dart';
import 'package:dart_nats/dart_nats.dart';

void main() {
  group('JetStream Codes', () {
    test('API codes constants', () {
      expect(JetStreamApiCodes.consumerNotFound, equals(10014));
      expect(JetStreamApiCodes.streamNotFound, equals(10059));
      expect(JetStreamApiCodes.streamAlreadyExists, equals(10058));
      expect(JetStreamApiCodes.jetStreamNotEnabledForAccount, equals(10039));
      expect(JetStreamApiCodes.streamWrongLastSequence, equals(10071));
      expect(JetStreamApiCodes.noMessageFound, equals(10037));
    });

    test('Status codes constants', () {
      expect(JetStreamStatusCodes.requestTimeout, equals(408));
      expect(JetStreamStatusCodes.noResponders, equals(503));
      expect(JetStreamStatusCodes.messageNotFound, equals(404));
      expect(JetStreamStatusCodes.idleHeartbeat, equals(100));
      expect(JetStreamStatusCodes.endOfBatch, equals(204));
    });
  });
}
