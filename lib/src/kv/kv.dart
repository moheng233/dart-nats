// Copyright 2024 The dart-nats Authors
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../client.dart';
import '../message.dart';
import '../jetstream/jsclient.dart';
import '../jetstream/jsm.dart';
import '../jetstream/jsapi_types.dart';
import '../jetstream/jserrors.dart';
import 'kv_types.dart';

const String _kvOperationHeader = 'KV-Operation';

/// Regular expression for valid bucket names
final RegExp _validBucketRe = RegExp(r'^[-\w]+$');

/// Regular expression for valid key names
final RegExp _validKeyRe = RegExp(r'^[-/=.\w]+$');

/// KV Manager for creating and managing KV buckets
class Kvm {
  final JetStreamManager _jsm;
  final JetStreamClient _js;

  Kvm._(this._jsm, this._js);

  /// Creates a KV manager from a NATS client
  static Future<Kvm> fromClient(Client nc) async {
    final jsm = await jetstreamManager(nc, JetStreamManagerOptions());
    final js = jetstream(nc);
    return Kvm._(jsm, js);
  }

  /// Creates a KV manager with existing JetStream client
  Kvm.fromJetStream(JetStreamClient js, JetStreamManager jsm)
      : _js = js,
        _jsm = jsm;

  /// Lists all KV bucket names
  Stream<String> list() async* {
    await for (final streamName in _jsm.listStreams()) {
      if (streamName.startsWith('KV_')) {
        yield streamName.substring(3); // Remove 'KV_' prefix
      }
    }
  }

  /// Creates a new KV bucket or binds to existing one
  Future<Kv> create(String bucket, [KvOptions? options]) async {
    _validateBucket(bucket);
    final opts = options ?? KvOptions();

    final streamName = 'KV_$bucket';
    final config = StreamConfig(
      name: streamName,
      subjects: ['\$KV.$bucket.>'],
      retention: RetentionPolicy.limits,
      maxMsgs: -1,
      maxBytes: opts.maxBytes ?? -1,
      maxAge: opts.ttl ?? 0,
      maxMsgSize: -1,
      storage: opts.storage,
      numReplicas: opts.replicas,
      description: opts.description,
      discard: DiscardPolicy.new_,
    );

    try {
      await _jsm.addStream(config);
    } on JetStreamApiException catch (e) {
      // If stream already exists, just bind to it
      if (e.apiError?.errCode != 10058) {
        rethrow;
      }
    }

    return Kv._(bucket, _js, _jsm);
  }

  /// Opens an existing KV bucket
  Future<Kv> open(String bucket) async {
    _validateBucket(bucket);
    final streamName = 'KV_$bucket';

    // Check if stream exists
    try {
      await _jsm.getStreamInfo(streamName);
    } catch (e) {
      throw JetStreamException('Bucket not found: $bucket');
    }

    return Kv._(bucket, _js, _jsm);
  }

  /// Deletes a KV bucket
  Future<bool> delete(String bucket) async {
    _validateBucket(bucket);
    final streamName = 'KV_$bucket';
    return await _jsm.deleteStream(streamName);
  }

  /// Gets status of a KV bucket
  Future<KvStatus> status(String bucket) async {
    _validateBucket(bucket);
    final streamName = 'KV_$bucket';
    final info = await _jsm.getStreamInfo(streamName);

    return KvStatus(
      bucket: bucket,
      description: info.config.description,
      values: info.state.messages,
      bytes: info.state.bytes,
      history: 1, // Simplified
      ttl: info.config.maxAge,
      storage: info.config.storage,
      replicas: info.config.numReplicas,
      sealed: false, // Simplified
    );
  }

  void _validateBucket(String bucket) {
    if (!_validBucketRe.hasMatch(bucket)) {
      throw ArgumentError('Invalid bucket name: $bucket');
    }
  }
}

/// KV bucket for key-value operations
class Kv {
  final String _bucket;
  final JetStreamClient _js;
  final JetStreamManager _jsm;

  Kv._(this._bucket, this._js, this._jsm);

  /// Gets the bucket name
  String get bucket => _bucket;

  /// Puts a value for a key
  Future<int> put(String key, Uint8List value) async {
    _validateKey(key);

    final subject = '\$KV.$_bucket.$key';
    final header = Header();
    header.add(_kvOperationHeader, 'PUT');

    final ack = await _js.publish(
      subject,
      value,
      options: JetStreamPublishOptions(headers: {
        _kvOperationHeader: 'PUT',
      }),
    );

    return ack.seq;
  }

  /// Puts a string value for a key
  Future<int> putString(String key, String value) async {
    return put(key, Uint8List.fromList(utf8.encode(value)));
  }

  /// Gets a value for a key
  Future<KvEntry?> get(String key) async {
    _validateKey(key);

    final subject = '\$KV.$_bucket.$key';

    try {
      // Request last message for the key
      final requestSubject = '\$JS.API.DIRECT.GET.KV_$_bucket';
      final request = jsonEncode({
        'last_by_subj': subject,
      });

      final response = await _js.nc.request(
        requestSubject,
        Uint8List.fromList(utf8.encode(request)),
        timeout: Duration(seconds: 5),
      );

      return _parseKvEntry(response, key);
    } catch (e) {
      return null;
    }
  }

  /// Deletes a key
  Future<void> delete(String key) async {
    _validateKey(key);

    final subject = '\$KV.$_bucket.$key';
    await _js.publish(
      subject,
      Uint8List(0),
      options: JetStreamPublishOptions(headers: {
        _kvOperationHeader: 'DEL',
      }),
    );
  }

  /// Purges all values for a key (keeping only delete marker)
  Future<void> purge(String key) async {
    _validateKey(key);

    final subject = '\$KV.$_bucket.$key';
    await _js.publish(
      subject,
      Uint8List(0),
      options: JetStreamPublishOptions(headers: {
        _kvOperationHeader: 'PURGE',
      }),
    );
  }

  /// Lists all keys in the bucket
  Stream<String> keys() async* {
    // This is a simplified implementation
    // In a full implementation, we'd query the stream for all keys
    final subject = '\$KV.$_bucket.>';
    final sub = _js.nc.sub(subject);

    final seen = <String>{};

    try {
      await for (final msg in sub.stream.timeout(Duration(seconds: 1))) {
        if (msg.subject != null) {
          final key = msg.subject!.substring('\$KV.$_bucket.'.length);
          if (!seen.contains(key)) {
            seen.add(key);
            yield key;
          }
        }
      }
    } on TimeoutException {
      // No more messages
    } finally {
      _js.nc.unSub(sub);
    }
  }

  /// Gets the bucket status
  Future<KvStatus> status() async {
    final streamName = 'KV_$_bucket';
    final info = await _jsm.getStreamInfo(streamName);

    return KvStatus(
      bucket: _bucket,
      description: info.config.description,
      values: info.state.messages,
      bytes: info.state.bytes,
      history: 1,
      ttl: info.config.maxAge,
      storage: info.config.storage,
      replicas: info.config.numReplicas,
      sealed: false,
    );
  }

  void _validateKey(String key) {
    if (key.startsWith('.') || key.endsWith('.') || !_validKeyRe.hasMatch(key)) {
      throw ArgumentError('Invalid key: $key');
    }
  }

  KvEntry? _parseKvEntry(Message msg, String key) {
    final operation = msg.header?.get(_kvOperationHeader);
    final kvOp = kvOperationFromString(operation);

    // Extract sequence from headers
    final seqStr = msg.header?.get('Nats-Sequence');
    final seq = seqStr != null ? int.tryParse(seqStr) ?? 1 : 1;

    // Extract timestamp
    final tsStr = msg.header?.get('Nats-Time-Stamp');
    final created = tsStr != null 
        ? DateTime.tryParse(tsStr) ?? DateTime.now()
        : DateTime.now();

    return KvEntry(
      bucket: _bucket,
      key: key,
      rawKey: msg.subject ?? '',
      value: msg.byte,
      created: created,
      revision: seq,
      operation: kvOp,
      length: msg.byte.length,
    );
  }
}
