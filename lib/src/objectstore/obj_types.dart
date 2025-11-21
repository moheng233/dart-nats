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

import 'package:json_annotation/json_annotation.dart';

import '../jetstream/jsapi_types.dart';
import '../message.dart';

part 'obj_types.g.dart';

/// Link to another object or bucket
@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class ObjectStoreLink {
  /// Creates an object store link
  ObjectStoreLink({
    required this.bucket,
    this.name,
  });

  /// Creates a link from JSON
  factory ObjectStoreLink.fromJson(Map<String, dynamic> json) =>
      _$ObjectStoreLinkFromJson(json);

  /// Name of the bucket storing the data
  final String bucket;

  /// Name of the object (empty means whole store)
  final String? name;

  /// Converts to JSON
  Map<String, dynamic> toJson() => _$ObjectStoreLinkToJson(this);
}

/// Metadata options for an object
@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class ObjectStoreMetaOptions {
  /// Creates object store meta options
  ObjectStoreMetaOptions({
    this.link,
    this.maxChunkSize,
  });

  /// Creates from JSON
  factory ObjectStoreMetaOptions.fromJson(Map<String, dynamic> json) =>
      _$ObjectStoreMetaOptionsFromJson(json);

  /// Link to another object
  final ObjectStoreLink? link;

  /// Maximum chunk size in bytes
  final int? maxChunkSize;

  /// Converts to JSON
  Map<String, dynamic> toJson() => _$ObjectStoreMetaOptionsToJson(this);
}

/// Metadata for an object
@JsonSerializable(
  fieldRename: FieldRename.snake,
  includeIfNull: false,
  explicitToJson: true,
)
class ObjectStoreMeta {
  /// Creates object store metadata
  ObjectStoreMeta({
    required this.name,
    this.description,
    this.headers,
    this.options,
    this.metadata,
  });

  /// Creates from JSON
  factory ObjectStoreMeta.fromJson(Map<String, dynamic> json) =>
      _$ObjectStoreMetaFromJson(json);

  /// Name of the object
  final String name;

  /// Description
  final String? description;

  /// Headers
  @JsonKey(ignore: true)
  final Header? headers;

  /// Options
  final ObjectStoreMetaOptions? options;

  /// Custom metadata
  final Map<String, String>? metadata;

  /// Converts to JSON
  Map<String, dynamic> toJson() => _$ObjectStoreMetaToJson(this);
}

/// Information about an object
@JsonSerializable(
  fieldRename: FieldRename.snake,
  includeIfNull: false,
  explicitToJson: true,
)
class ObjectInfo extends ObjectStoreMeta {
  /// Creates object info
  ObjectInfo({
    required this.bucket,
    required this.nuid,
    required this.size,
    required this.chunks,
    required this.digest,
    required this.deleted,
    required this.mtime,
    required this.revision,
    required super.name,
    super.description,
    super.headers,
    super.options,
    super.metadata,
  });

  /// Creates from JSON
  factory ObjectInfo.fromJson(Map<String, dynamic> json) =>
      _$ObjectInfoFromJson(json);

  /// Bucket name
  final String bucket;

  /// Unique identifier
  final String nuid;

  /// Size in bytes
  final int size;

  /// Number of chunks
  final int chunks;

  /// Cryptographic digest
  final String digest;

  /// Whether the object is deleted
  @JsonKey(defaultValue: false)
  final bool deleted;

  /// Modification time
  final String mtime;

  /// Revision number
  final int revision;

  @override
  Map<String, dynamic> toJson() => _$ObjectInfoToJson(this);
}

/// Watch entry with update information
@JsonSerializable(fieldRename: FieldRename.snake)
class ObjectWatchInfo extends ObjectInfo {
  /// Creates object watch info
  ObjectWatchInfo({
    required super.bucket,
    required super.nuid,
    required super.size,
    required super.chunks,
    required super.digest,
    required super.deleted,
    required super.mtime,
    required super.revision,
    required super.name,
    required this.isUpdate,
    super.description,
    super.headers,
    super.options,
    super.metadata,
  });

  /// Creates from JSON
  factory ObjectWatchInfo.fromJson(Map<String, dynamic> json) =>
      _$ObjectWatchInfoFromJson(json);

  /// Whether this is an update
  final bool isUpdate;

  /// Converts to JSON
  @override
  Map<String, dynamic> toJson() => _$ObjectWatchInfoToJson(this);
}

/// Status of an object store
@JsonSerializable(fieldRename: FieldRename.snake)
class ObjectStoreStatus {
  /// Creates object store status
  ObjectStoreStatus({
    required this.bucket,
    required this.description,
    required this.ttl,
    required this.storage,
    required this.replicas,
    required this.sealed,
    required this.size,
    this.backingStore = 'JetStream',
  });

  /// Bucket name
  final String bucket;

  /// Description
  final String description;

  /// Time-to-live in nanoseconds
  final int ttl;

  /// Storage type
  final StorageType storage;

  /// Number of replicas
  final int replicas;

  /// Whether sealed
  final bool sealed;

  /// Size in bytes
  final int size;

  /// Backing store (always "JetStream")
  final String backingStore;
}

/// Options for creating an object store
@JsonSerializable(fieldRename: FieldRename.snake)
class ObjectStoreOptions {
  /// Creates object store options
  ObjectStoreOptions({
    this.description,
    this.ttl,
    this.storage = StorageType.file,
    this.replicas = 1,
    this.maxBytes,
  });

  /// Description
  final String? description;

  /// Time-to-live in nanoseconds
  final int? ttl;

  /// Storage type
  final StorageType storage;

  /// Number of replicas
  final int replicas;

  /// Maximum bytes
  final int? maxBytes;
}
