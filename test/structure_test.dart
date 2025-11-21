import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_nats/dart_nats.dart';
import 'package:test/test.dart';

import 'model/student.dart';

void main() {
  group('all', () {
    test('string to string', () async {
      final client = NatsClient();

      await client.connect(
        Uri.parse('nats://localhost:4222'),
        retryInterval: 1,
      );
      final sub = client.sub<String>('subject1', jsonDecoder: string2string);
      await client.pub('subject1', Uint8List.fromList('message1'.codeUnits));
      final msg = await sub.stream.first;
      await client.close();
      expect(msg.data, equals('message1'));
    });

    test('sub', () async {
      final client = NatsClient();
      await client.connect(
        Uri.parse('nats://localhost:4222'),
        retryInterval: 1,
      );
      final sub = client.sub<Student>('subject1', jsonDecoder: json2Student);
      final student = Student('id', 'name', 1);
      await client.pubString('subject1', jsonEncode(student.toJson()));
      final msg = await sub.stream.first;
      await client.close();
      expect(msg.data.id, student.id);
      expect(msg.data.name, student.name);
      expect(msg.data.score, student.score);
    });
    test('sub register jsonDecoder', () async {
      final client = NatsClient();
      await client.connect(
        Uri.parse('nats://localhost:4222'),
        retryInterval: 1,
      );
      client.registerJsonDecoder<Student>(json2Student);
      final sub = client.sub<Student>('subject1');
      final student = Student('id', 'name', 1);
      await client.pubString('subject1', jsonEncode(student.toJson()));
      final msg = await sub.stream.first;
      await client.close();
      expect(msg.data.id, student.id);
      expect(msg.data.name, student.name);
      expect(msg.data.score, student.score);
    });
    test('sub no type', () async {
      final client = NatsClient();
      await client.connect(
        Uri.parse('nats://localhost:4222'),
        retryInterval: 1,
      );
      final sub = client.sub('subject1', jsonDecoder: json2Student);
      final student = Student('id', 'name', 1);
      await client.pubString('subject1', jsonEncode(student.toJson()));
      final msg = await sub.stream.first;
      await client.close();
      expect(msg.data.id, student.id);
      expect(msg.data.name, student.name);
      expect(msg.data.score, student.score);
    });
    test('sub no type no jsonDecoder', () async {
      final client = NatsClient();
      await client.connect(
        Uri.parse('nats://localhost:4222'),
        retryInterval: 1,
      );
      final sub = client.sub('subject1');
      final student = Student('id', 'name', 1);
      await client.pubString('subject1', jsonEncode(student.toJson()));
      final msg = await sub.stream.first;
      await client.close();
      if (msg.data is! Uint8List) {
        throw Exception('missing data type');
      }
    });
    test('request', () async {
      final server = NatsClient();
      await server.connect(Uri.parse('nats://localhost:4222'));
      server.registerJsonDecoder<Student>(json2Student);
      final service = server.sub<Student>('service');
      unawaited(
        service.stream.first.then((m) {
          m.respondString(jsonEncode(m.data.toJson()));
        }),
      );

      final client = NatsClient();
      final s1 = Student('id', 'name', 1);
      await client.connect(Uri.parse('nats://localhost:4222'));
      final receive = await client.requestString(
        'service',
        jsonEncode(s1.toJson()),
      );
      final s2 = Student.fromJson(
        jsonDecode(receive.string) as Map<String, dynamic>,
      );
      await client.close();
      await server.close();
      expect(s1.score, equals(s2.score));
    });
    test('request register jsonDecoder', () async {
      final server = NatsClient()..registerJsonDecoder<Student>(json2Student);
      await server.connect(Uri.parse('nats://localhost:4222'));
      final service = server.sub<Student>('service');
      unawaited(
        service.stream.first.then((m) {
          m.respondString(jsonEncode(m.data.toJson()));
        }),
      );

      final client = NatsClient()..registerJsonDecoder<Student>(json2Student);
      final s1 = Student('id', 'name', 1);
      await client.connect(Uri.parse('nats://localhost:4222'));
      final receive = await client.requestString<Student>(
        'service',
        jsonEncode(s1.toJson()),
      );
      final s2 = receive.data;
      await client.close();
      await server.close();
      expect(s1.score, equals(s2.score));
    });
  });
}

String string2string(String input) {
  return input;
}

Student json2Student(String json) {
  return Student.fromJson(jsonDecode(json) as Map<String, dynamic>);
}

String student2json(Student student) {
  return jsonEncode(student.toJson());
}
