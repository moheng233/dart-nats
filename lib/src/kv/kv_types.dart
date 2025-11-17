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

import 'dart:convert';
import 'dart:typed_data';

import '../jetstream/jsapi_types.dart';

/// KV operation types
enum KvOperation {
  /// Put operation
  put,

  /// Delete operation
  del,

  /// Purge operation
  purge,
}

/// KV entry representing a key-value pair
class KvEntry {
  /// The bucket name
  final String bucket;

  /// The key
  final String key;

  /// The raw key (with bucket prefix)
  final String rawKey;

  /// The value as bytes
  final Uint8List value;

  /// When the entry was created
  final DateTime created;

  /// The revision number
  final int revision;

  /// The operation type
  final KvOperation operation;

  /// The value length
  final int length;

  /// The delta (time since last update in nanoseconds)
  final int? delta;

  /// Creates a KV entry
  KvEntry({
    required this.bucket,
    required this.key,
    required this.rawKey,
    required this.value,
    required this.created,
    required this.revision,
    required this.operation,
    required this.length,
    this.delta,
  });

  /// Parses the value as JSON
  T json<T>() {
    return jsonDecode(string()) as T;
  }

  /// Returns the value as a string
  String string() {
    return utf8.decode(value);
  }

  /// Whether this entry represents a deletion
  bool get isDeleted => operation == KvOperation.del || operation == KvOperation.purge;
}

/// KV entry with update information for watch operations
class KvWatchEntry extends KvEntry {
  /// Whether this is an update to an existing key
  final bool isUpdate;

  /// Creates a KV watch entry
  KvWatchEntry({
    required String bucket,
    required String key,
    required String rawKey,
    required Uint8List value,
    required DateTime created,
    required int revision,
    required KvOperation operation,
    required int length,
    int? delta,
    required this.isUpdate,
  }) : super(
          bucket: bucket,
          key: key,
          rawKey: rawKey,
          value: value,
          created: created,
          revision: revision,
          operation: operation,
          length: length,
          delta: delta,
        );
}

/// KV bucket status
class KvStatus {
  /// The bucket name
  final String bucket;

  /// Description of the bucket
  final String? description;

  /// Number of entries
  final int values;

  /// Total bytes
  final int bytes;

  /// Number of history entries kept
  final int history;

  /// Time-to-live in nanoseconds
  final int? ttl;

  /// Storage type
  final StorageType storage;

  /// Number of replicas
  final int replicas;

  /// Whether the bucket is sealed
  final bool sealed;

  /// Creates KV status
  KvStatus({
    required this.bucket,
    this.description,
    required this.values,
    required this.bytes,
    required this.history,
    this.ttl,
    required this.storage,
    required this.replicas,
    required this.sealed,
  });
}

/// Options for creating a KV bucket
class KvOptions {
  /// Description of the bucket
  final String? description;

  /// Number of history entries to keep (default: 1)
  final int history;

  /// Time-to-live in nanoseconds
  final int? ttl;

  /// Maximum bytes for the bucket
  final int? maxBytes;

  /// Storage type (default: file)
  final StorageType storage;

  /// Number of replicas (default: 1)
  final int replicas;

  /// Whether to re-publish updates
  final bool? republish;

  /// Mirror configuration
  final StreamSource? mirror;

  /// Source streams for aggregation
  final List<StreamSource>? sources;

  /// Creates KV options
  KvOptions({
    this.description,
    this.history = 1,
    this.ttl,
    this.maxBytes,
    this.storage = StorageType.file,
    this.replicas = 1,
    this.republish,
    this.mirror,
    this.sources,
  });
}

/// Helper to convert operation enum to string
String kvOperationToString(KvOperation op) {
  switch (op) {
    case KvOperation.put:
      return 'PUT';
    case KvOperation.del:
      return 'DEL';
    case KvOperation.purge:
      return 'PURGE';
  }
}

/// Helper to convert string to operation enum
KvOperation kvOperationFromString(String? op) {
  switch (op?.toUpperCase()) {
    case 'DEL':
      return KvOperation.del;
    case 'PURGE':
      return KvOperation.purge;
    default:
      return KvOperation.put;
  }
}
