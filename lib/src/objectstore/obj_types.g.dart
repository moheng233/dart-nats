// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'obj_types.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ObjectStoreLink _$ObjectStoreLinkFromJson(Map<String, dynamic> json) =>
    ObjectStoreLink(
      bucket: json['bucket'] as String,
      name: json['name'] as String?,
    );

Map<String, dynamic> _$ObjectStoreLinkToJson(ObjectStoreLink instance) =>
    <String, dynamic>{'bucket': instance.bucket, 'name': ?instance.name};

ObjectStoreMetaOptions _$ObjectStoreMetaOptionsFromJson(
  Map<String, dynamic> json,
) => ObjectStoreMetaOptions(
  link: json['link'] == null
      ? null
      : ObjectStoreLink.fromJson(json['link'] as Map<String, dynamic>),
  maxChunkSize: (json['max_chunk_size'] as num?)?.toInt(),
);

Map<String, dynamic> _$ObjectStoreMetaOptionsToJson(
  ObjectStoreMetaOptions instance,
) => <String, dynamic>{
  'link': ?instance.link,
  'max_chunk_size': ?instance.maxChunkSize,
};

ObjectStoreMeta _$ObjectStoreMetaFromJson(Map<String, dynamic> json) =>
    ObjectStoreMeta(
      name: json['name'] as String,
      description: json['description'] as String?,
      options: json['options'] == null
          ? null
          : ObjectStoreMetaOptions.fromJson(
              json['options'] as Map<String, dynamic>,
            ),
      metadata: (json['metadata'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
    );

Map<String, dynamic> _$ObjectStoreMetaToJson(ObjectStoreMeta instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': ?instance.description,
      'options': ?instance.options?.toJson(),
      'metadata': ?instance.metadata,
    };

ObjectInfo _$ObjectInfoFromJson(Map<String, dynamic> json) => ObjectInfo(
  bucket: json['bucket'] as String,
  nuid: json['nuid'] as String,
  size: (json['size'] as num).toInt(),
  chunks: (json['chunks'] as num).toInt(),
  digest: json['digest'] as String,
  deleted: json['deleted'] as bool? ?? false,
  mtime: json['mtime'] as String,
  revision: (json['revision'] as num).toInt(),
  name: json['name'] as String,
  description: json['description'] as String?,
  options: json['options'] == null
      ? null
      : ObjectStoreMetaOptions.fromJson(
          json['options'] as Map<String, dynamic>,
        ),
  metadata: (json['metadata'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
);

Map<String, dynamic> _$ObjectInfoToJson(ObjectInfo instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': ?instance.description,
      'options': ?instance.options?.toJson(),
      'metadata': ?instance.metadata,
      'bucket': instance.bucket,
      'nuid': instance.nuid,
      'size': instance.size,
      'chunks': instance.chunks,
      'digest': instance.digest,
      'deleted': instance.deleted,
      'mtime': instance.mtime,
      'revision': instance.revision,
    };

ObjectWatchInfo _$ObjectWatchInfoFromJson(Map<String, dynamic> json) =>
    ObjectWatchInfo(
      bucket: json['bucket'] as String,
      nuid: json['nuid'] as String,
      size: (json['size'] as num).toInt(),
      chunks: (json['chunks'] as num).toInt(),
      digest: json['digest'] as String,
      deleted: json['deleted'] as bool? ?? false,
      mtime: json['mtime'] as String,
      revision: (json['revision'] as num).toInt(),
      name: json['name'] as String,
      isUpdate: json['is_update'] as bool,
      description: json['description'] as String?,
      options: json['options'] == null
          ? null
          : ObjectStoreMetaOptions.fromJson(
              json['options'] as Map<String, dynamic>,
            ),
      metadata: (json['metadata'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
    );

Map<String, dynamic> _$ObjectWatchInfoToJson(ObjectWatchInfo instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'options': instance.options,
      'metadata': instance.metadata,
      'bucket': instance.bucket,
      'nuid': instance.nuid,
      'size': instance.size,
      'chunks': instance.chunks,
      'digest': instance.digest,
      'deleted': instance.deleted,
      'mtime': instance.mtime,
      'revision': instance.revision,
      'is_update': instance.isUpdate,
    };

ObjectStoreStatus _$ObjectStoreStatusFromJson(Map<String, dynamic> json) =>
    ObjectStoreStatus(
      bucket: json['bucket'] as String,
      description: json['description'] as String,
      ttl: (json['ttl'] as num).toInt(),
      storage: $enumDecode(_$StorageTypeEnumMap, json['storage']),
      replicas: (json['replicas'] as num).toInt(),
      sealed: json['sealed'] as bool,
      size: (json['size'] as num).toInt(),
      backingStore: json['backing_store'] as String? ?? 'JetStream',
    );

Map<String, dynamic> _$ObjectStoreStatusToJson(ObjectStoreStatus instance) =>
    <String, dynamic>{
      'bucket': instance.bucket,
      'description': instance.description,
      'ttl': instance.ttl,
      'storage': _$StorageTypeEnumMap[instance.storage]!,
      'replicas': instance.replicas,
      'sealed': instance.sealed,
      'size': instance.size,
      'backing_store': instance.backingStore,
    };

const _$StorageTypeEnumMap = {
  StorageType.file: 'file',
  StorageType.memory: 'memory',
};

ObjectStoreOptions _$ObjectStoreOptionsFromJson(Map<String, dynamic> json) =>
    ObjectStoreOptions(
      description: json['description'] as String?,
      ttl: (json['ttl'] as num?)?.toInt(),
      storage:
          $enumDecodeNullable(_$StorageTypeEnumMap, json['storage']) ??
          StorageType.file,
      replicas: (json['replicas'] as num?)?.toInt() ?? 1,
      maxBytes: (json['max_bytes'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ObjectStoreOptionsToJson(ObjectStoreOptions instance) =>
    <String, dynamic>{
      'description': instance.description,
      'ttl': instance.ttl,
      'storage': _$StorageTypeEnumMap[instance.storage]!,
      'replicas': instance.replicas,
      'max_bytes': instance.maxBytes,
    };
