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

import '../jetstream/jsapi_types.dart';
import '../message.dart';

/// Link to another object or bucket
class ObjectStoreLink {
  /// Name of the bucket storing the data
  final String bucket;

  /// Name of the object (empty means whole store)
  final String? name;

  /// Creates an object store link
  ObjectStoreLink({
    required this.bucket,
    this.name,
  });

  /// Creates a link from JSON
  factory ObjectStoreLink.fromJson(Map<String, dynamic> json) {
    return ObjectStoreLink(
      bucket: json['bucket'] as String,
      name: json['name'] as String?,
    );
  }

  /// Converts to JSON
  Map<String, dynamic> toJson() {
    return {
      'bucket': bucket,
      if (name != null) 'name': name,
    };
  }
}

/// Metadata options for an object
class ObjectStoreMetaOptions {
  /// Link to another object
  final ObjectStoreLink? link;

  /// Maximum chunk size in bytes
  final int? maxChunkSize;

  /// Creates object store meta options
  ObjectStoreMetaOptions({
    this.link,
    this.maxChunkSize,
  });

  /// Creates from JSON
  factory ObjectStoreMetaOptions.fromJson(Map<String, dynamic> json) {
    return ObjectStoreMetaOptions(
      link: json['link'] != null
          ? ObjectStoreLink.fromJson(json['link'] as Map<String, dynamic>)
          : null,
      maxChunkSize: json['max_chunk_size'] as int?,
    );
  }

  /// Converts to JSON
  Map<String, dynamic> toJson() {
    return {
      if (link != null) 'link': link!.toJson(),
      if (maxChunkSize != null) 'max_chunk_size': maxChunkSize,
    };
  }
}

/// Metadata for an object
class ObjectStoreMeta {
  /// Name of the object
  final String name;

  /// Description
  final String? description;

  /// Headers
  final Header? headers;

  /// Options
  final ObjectStoreMetaOptions? options;

  /// Custom metadata
  final Map<String, String>? metadata;

  /// Creates object store metadata
  ObjectStoreMeta({
    required this.name,
    this.description,
    this.headers,
    this.options,
    this.metadata,
  });

  /// Creates from JSON
  factory ObjectStoreMeta.fromJson(Map<String, dynamic> json) {
    return ObjectStoreMeta(
      name: json['name'] as String,
      description: json['description'] as String?,
      options: json['options'] != null
          ? ObjectStoreMetaOptions.fromJson(
              json['options'] as Map<String, dynamic>)
          : null,
      metadata: (json['metadata'] as Map<String, dynamic>?)?.cast<String, String>(),
    );
  }

  /// Converts to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (description != null) 'description': description,
      if (options != null) 'options': options!.toJson(),
      if (metadata != null) 'metadata': metadata,
    };
  }
}

/// Information about an object
class ObjectInfo extends ObjectStoreMeta {
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
  final bool deleted;

  /// Modification time
  final String mtime;

  /// Revision number
  final int revision;

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
    required String name,
    String? description,
    Header? headers,
    ObjectStoreMetaOptions? options,
    Map<String, String>? metadata,
  }) : super(
          name: name,
          description: description,
          headers: headers,
          options: options,
          metadata: metadata,
        );

  /// Creates from JSON
  factory ObjectInfo.fromJson(Map<String, dynamic> json) {
    return ObjectInfo(
      bucket: json['bucket'] as String,
      nuid: json['nuid'] as String,
      size: json['size'] as int,
      chunks: json['chunks'] as int,
      digest: json['digest'] as String,
      deleted: json['deleted'] as bool? ?? false,
      mtime: json['mtime'] as String,
      revision: json['revision'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      options: json['options'] != null
          ? ObjectStoreMetaOptions.fromJson(
              json['options'] as Map<String, dynamic>)
          : null,
      metadata: (json['metadata'] as Map<String, dynamic>?)?.cast<String, String>(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'bucket': bucket,
      'nuid': nuid,
      'size': size,
      'chunks': chunks,
      'digest': digest,
      'deleted': deleted,
      'mtime': mtime,
      'revision': revision,
    };
  }
}

/// Watch entry with update information
class ObjectWatchInfo extends ObjectInfo {
  /// Whether this is an update
  final bool isUpdate;

  /// Creates object watch info
  ObjectWatchInfo({
    required String bucket,
    required String nuid,
    required int size,
    required int chunks,
    required String digest,
    required bool deleted,
    required String mtime,
    required int revision,
    required String name,
    String? description,
    Header? headers,
    ObjectStoreMetaOptions? options,
    Map<String, String>? metadata,
    required this.isUpdate,
  }) : super(
          bucket: bucket,
          nuid: nuid,
          size: size,
          chunks: chunks,
          digest: digest,
          deleted: deleted,
          mtime: mtime,
          revision: revision,
          name: name,
          description: description,
          headers: headers,
          options: options,
          metadata: metadata,
        );
}

/// Status of an object store
class ObjectStoreStatus {
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
}

/// Options for creating an object store
class ObjectStoreOptions {
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

  /// Creates object store options
  ObjectStoreOptions({
    this.description,
    this.ttl,
    this.storage = StorageType.file,
    this.replicas = 1,
    this.maxBytes,
  });
}
