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
import 'package:crypto/crypto.dart';

import '../client.dart';
import '../inbox.dart';
import '../jetstream/jsclient.dart';
import '../jetstream/jsm.dart';
import '../jetstream/jsapi_types.dart';
import '../jetstream/jserrors.dart';
import 'obj_types.dart';

/// Default chunk size for object storage (128KB)
const int _defaultChunkSize = 128 * 1024;

/// Maximum chunk size (limited by JetStream message size)
const int _maxChunkSize = 1024 * 1024;

/// Regular expression for valid bucket names
final RegExp _validBucketRe = RegExp(r'^[-\w]+$');

/// Object Store Manager for creating and managing object stores
class Objm {
  final JetStreamManager _jsm;
  final JetStreamClient _js;

  Objm._(this._jsm, this._js);

  /// Creates an object store manager from a NATS client
  static Future<Objm> fromClient(NatsClient nc) async {
    final jsm = await jetstreamManager(nc, JetStreamManagerOptions());
    final js = jetstream(nc);
    return Objm._(jsm, js);
  }

  /// Creates from existing JetStream client
  Objm.fromJetStream(JetStreamClient js, JetStreamManager jsm)
      : _js = js,
        _jsm = jsm;

  /// Lists all object store bucket names
  Stream<String> list() async* {
    await for (final streamName in _jsm.listStreams()) {
      if (streamName.startsWith('OBJ_')) {
        yield streamName.substring(4); // Remove 'OBJ_' prefix
      }
    }
  }

  /// Creates a new object store or binds to existing one
  Future<ObjectStore> create(String bucket, [ObjectStoreOptions? options]) async {
    _validateBucket(bucket);
    final opts = options ?? ObjectStoreOptions();

    final streamName = 'OBJ_$bucket';
    final config = StreamConfig(
      name: streamName,
      subjects: ['\$O.$bucket.C.>', '\$O.$bucket.M.>'],
      retention: RetentionPolicy.limits,
      maxMsgs: -1,
      maxBytes: opts.maxBytes ?? -1,
      maxAge: opts.ttl ?? 0,
      maxMsgSize: _maxChunkSize,
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

    return ObjectStore._(bucket, _js, _jsm);
  }

  /// Opens an existing object store
  Future<ObjectStore> open(String bucket) async {
    _validateBucket(bucket);
    final streamName = 'OBJ_$bucket';

    // Check if stream exists
    try {
      await _jsm.getStreamInfo(streamName);
    } catch (e) {
      throw JetStreamException('Object store not found: $bucket');
    }

    return ObjectStore._(bucket, _js, _jsm);
  }

  /// Deletes an object store
  Future<bool> delete(String bucket) async {
    _validateBucket(bucket);
    final streamName = 'OBJ_$bucket';
    return await _jsm.deleteStream(streamName);
  }

  /// Gets status of an object store
  Future<ObjectStoreStatus> status(String bucket) async {
    _validateBucket(bucket);
    final streamName = 'OBJ_$bucket';
    final info = await _jsm.getStreamInfo(streamName);

    return ObjectStoreStatus(
      bucket: bucket,
      description: info.config.description ?? '',
      ttl: info.config.maxAge,
      storage: info.config.storage,
      replicas: info.config.numReplicas,
      sealed: false,
      size: info.state.bytes,
    );
  }

  void _validateBucket(String bucket) {
    if (!_validBucketRe.hasMatch(bucket)) {
      throw ArgumentError('Invalid bucket name: $bucket');
    }
  }
}

/// Object Store for storing and retrieving objects
class ObjectStore {
  final String _bucket;
  final JetStreamClient _js;
  final JetStreamManager _jsm;

  ObjectStore._(this._bucket, this._js, this._jsm);

  /// Gets the bucket name
  String get bucket => _bucket;

  /// Puts an object
  Future<ObjectInfo> put(ObjectStoreMeta meta, Uint8List data) async {
    final nuid = Nuid().next();
    final chunkSize = meta.options?.maxChunkSize ?? _defaultChunkSize;
    final chunks = (data.length / chunkSize).ceil();

    // Calculate digest (SHA-256)
    final digest = sha256.convert(data).toString();

    // Store metadata
    final metaSubject = '\$O.$_bucket.M.$nuid';
    final metaData = jsonEncode({
      'name': meta.name,
      'description': meta.description,
      'size': data.length,
      'chunks': chunks,
      'digest': 'SHA-256=$digest',
      if (meta.metadata != null) 'metadata': meta.metadata,
    });

    await _js.publishString(metaSubject, metaData);

    // Store chunks
    for (var i = 0; i < chunks; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize > data.length) ? data.length : start + chunkSize;
      final chunk = data.sublist(start, end);

      final chunkSubject = '\$O.$_bucket.C.$nuid.$i';
      await _js.publish(chunkSubject, chunk);
    }

    return ObjectInfo(
      bucket: _bucket,
      nuid: nuid,
      size: data.length,
      chunks: chunks,
      digest: 'SHA-256=$digest',
      deleted: false,
      mtime: DateTime.now().toUtc().toIso8601String(),
      revision: 1,
      name: meta.name,
      description: meta.description,
      metadata: meta.metadata,
    );
  }

  /// Gets an object
  Future<Uint8List?> get(String name) async {
    final info = await getInfo(name);
    if (info == null || info.deleted) {
      return null;
    }

    // Retrieve all chunks
    final chunks = <Uint8List>[];
    for (var i = 0; i < info.chunks; i++) {
      final chunkSubject = '\$O.$_bucket.C.${info.nuid}.$i';

      try {
        final requestSubject = '\$JS.API.DIRECT.GET.OBJ_$_bucket';
        final request = jsonEncode({
          'last_by_subj': chunkSubject,
        });

        final response = await _js.nc.request(
          requestSubject,
          Uint8List.fromList(utf8.encode(request)),
          timeout: Duration(seconds: 5),
        );

        chunks.add(response.byte);
      } catch (e) {
        return null;
      }
    }

    // Combine chunks
    final totalSize = chunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
    final result = Uint8List(totalSize);
    var offset = 0;
    for (final chunk in chunks) {
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    return result;
  }

  /// Gets object info by name
  Future<ObjectInfo?> getInfo(String name) async {
    // This is simplified - in a full implementation,
    // we'd maintain an index of names to nuids
    final metaSubject = '\$O.$_bucket.M.>';

    try {
      final requestSubject = '\$JS.API.DIRECT.GET.OBJ_$_bucket';
      final request = jsonEncode({
        'last_by_subj': metaSubject,
      });

      final response = await _js.nc.request(
        requestSubject,
        Uint8List.fromList(utf8.encode(request)),
        timeout: Duration(seconds: 5),
      );

      final meta = jsonDecode(utf8.decode(response.byte)) as Map<String, dynamic>;
      if (meta['name'] == name) {
        return ObjectInfo.fromJson({
          ...meta,
          'bucket': _bucket,
          'deleted': false,
          'revision': 1,
        });
      }
    } catch (e) {
      // Ignore
    }

    return null;
  }

  /// Deletes an object
  Future<void> delete(String name) async {
    final info = await getInfo(name);
    if (info == null) {
      throw JetStreamException('Object not found: $name');
    }

    // Publish delete marker
    final metaSubject = '\$O.$_bucket.M.${info.nuid}';
    final metaData = jsonEncode({
      'name': name,
      'deleted': true,
    });

    await _js.publishString(metaSubject, metaData);
  }

  /// Lists all object names
  Stream<String> list() async* {
    // Simplified implementation
    final metaSubject = '\$O.$_bucket.M.>';
    final sub = _js.nc.sub(metaSubject);

    final seen = <String>{};

    try {
      await for (final msg in sub.stream.timeout(Duration(seconds: 1))) {
        try {
          final meta = jsonDecode(utf8.decode(msg.byte)) as Map<String, dynamic>;
          final name = meta['name'] as String?;
          final deleted = meta['deleted'] as bool? ?? false;

          if (name != null && !deleted && !seen.contains(name)) {
            seen.add(name);
            yield name;
          }
        } catch (e) {
          // Skip invalid entries
        }
      }
    } on TimeoutException {
      // No more messages
    } finally {
      _js.nc.unSub(sub);
    }
  }

  /// Gets the object store status
  Future<ObjectStoreStatus> status() async {
    final streamName = 'OBJ_$_bucket';
    final info = await _jsm.getStreamInfo(streamName);

    return ObjectStoreStatus(
      bucket: _bucket,
      description: info.config.description ?? '',
      ttl: info.config.maxAge,
      storage: info.config.storage,
      replicas: info.config.numReplicas,
      sealed: false,
      size: info.state.bytes,
    );
  }
}
