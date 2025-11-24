// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'jsapi_types.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApiError _$ApiErrorFromJson(Map<String, dynamic> json) => ApiError(
  code: (json['code'] as num).toInt(),
  description: json['description'] as String,
  errCode: (json['err_code'] as num?)?.toInt(),
);

Map<String, dynamic> _$ApiErrorToJson(ApiError instance) => <String, dynamic>{
  'code': instance.code,
  'description': instance.description,
  'err_code': instance.errCode,
};

ApiResponse _$ApiResponseFromJson(Map<String, dynamic> json) => ApiResponse(
  type: json['type'] as String,
  error: json['error'] == null
      ? null
      : ApiError.fromJson(json['error'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ApiResponseToJson(ApiResponse instance) =>
    <String, dynamic>{'type': instance.type, 'error': instance.error};

StreamState _$StreamStateFromJson(Map<String, dynamic> json) => StreamState(
  messages: (json['messages'] as num).toInt(),
  bytes: (json['bytes'] as num).toInt(),
  firstSeq: (json['first_seq'] as num).toInt(),
  lastSeq: (json['last_seq'] as num).toInt(),
  consumerCount: (json['consumer_count'] as num).toInt(),
  firstTs: json['first_ts'] as String?,
  lastTs: json['last_ts'] as String?,
);

Map<String, dynamic> _$StreamStateToJson(StreamState instance) =>
    <String, dynamic>{
      'messages': instance.messages,
      'bytes': instance.bytes,
      'first_seq': instance.firstSeq,
      'first_ts': instance.firstTs,
      'last_seq': instance.lastSeq,
      'last_ts': instance.lastTs,
      'consumer_count': instance.consumerCount,
    };

StreamSource _$StreamSourceFromJson(Map<String, dynamic> json) => StreamSource(
  name: json['name'] as String,
  optStartSeq: (json['opt_start_seq'] as num?)?.toInt(),
  optStartTime: json['opt_start_time'] as String?,
  filterSubject: json['filter_subject'] as String?,
  mirrorDirect: json['mirror_direct'] as bool?,
);

Map<String, dynamic> _$StreamSourceToJson(StreamSource instance) =>
    <String, dynamic>{
      'name': instance.name,
      'opt_start_seq': instance.optStartSeq,
      'opt_start_time': instance.optStartTime,
      'filter_subject': instance.filterSubject,
      'mirror_direct': instance.mirrorDirect,
    };

Placement _$PlacementFromJson(Map<String, dynamic> json) => Placement(
  cluster: json['cluster'] as String?,
  tags: (json['tags'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
);

Map<String, dynamic> _$PlacementToJson(Placement instance) => <String, dynamic>{
  'cluster': instance.cluster,
  'tags': instance.tags,
};

Republish _$RepublishFromJson(Map<String, dynamic> json) => Republish(
  src: json['src'] as String?,
  dest: json['dest'] as String?,
  headers: (json['headers'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
);

Map<String, dynamic> _$RepublishToJson(Republish instance) => <String, dynamic>{
  'src': instance.src,
  'dest': instance.dest,
  'headers': instance.headers,
};

SubjectTransformConfig _$SubjectTransformConfigFromJson(
  Map<String, dynamic> json,
) => SubjectTransformConfig(rule: json['rule'] as String?);

Map<String, dynamic> _$SubjectTransformConfigToJson(
  SubjectTransformConfig instance,
) => <String, dynamic>{'rule': instance.rule};

StreamConsumerLimits _$StreamConsumerLimitsFromJson(
  Map<String, dynamic> json,
) => StreamConsumerLimits(
  inactiveThreshold: (json['inactive_threshold'] as num?)?.toInt(),
  maxAckPending: (json['max_ack_pending'] as num?)?.toInt(),
);

Map<String, dynamic> _$StreamConsumerLimitsToJson(
  StreamConsumerLimits instance,
) => <String, dynamic>{
  'inactive_threshold': instance.inactiveThreshold,
  'max_ack_pending': instance.maxAckPending,
};

StreamUpdateConfig _$StreamUpdateConfigFromJson(Map<String, dynamic> json) =>
    StreamUpdateConfig(
      subjects: (json['subjects'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      description: json['description'] as String?,
      maxMsgsPerSubject: (json['max_msgs_per_subject'] as num?)?.toInt(),
      maxMsgs: (json['max_msgs'] as num?)?.toInt() ?? -1,
      maxAge: (json['max_age'] as num?)?.toInt() ?? 0,
      maxBytes: (json['max_bytes'] as num?)?.toInt() ?? -1,
      maxMsgSize: (json['max_msg_size'] as num?)?.toInt() ?? -1,
      discard: $enumDecodeNullable(_$DiscardPolicyEnumMap, json['discard']),
      discardNewPerSubject: json['discard_new_per_subject'] as bool?,
      noAck: json['no_ack'] as bool?,
      duplicateWindow: (json['duplicate_window'] as num?)?.toInt(),
      sources: (json['sources'] as List<dynamic>?)
          ?.map((e) => StreamSource.fromJson(e as Map<String, dynamic>))
          .toList(),
      allowRollupHdrs: json['allow_rollup_hdrs'] as bool?,
      numReplicas: (json['num_replicas'] as num?)?.toInt() ?? 1,
      placement: json['placement'] == null
          ? null
          : Placement.fromJson(json['placement'] as Map<String, dynamic>),
      denyDelete: json['deny_delete'] as bool?,
      denyPurge: json['deny_purge'] as bool?,
      allowDirect: json['allow_direct'] as bool?,
      mirrorDirect: json['mirror_direct'] as bool?,
      republish: json['republish'] == null
          ? null
          : Republish.fromJson(json['republish'] as Map<String, dynamic>),
      metadata: (json['metadata'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      subjectTransform: json['subject_transform'] == null
          ? null
          : SubjectTransformConfig.fromJson(
              json['subject_transform'] as Map<String, dynamic>,
            ),
      compression: $enumDecodeNullable(
        _$StoreCompressionEnumMap,
        json['compression'],
      ),
      consumerLimits: json['consumer_limits'] == null
          ? null
          : StreamConsumerLimits.fromJson(
              json['consumer_limits'] as Map<String, dynamic>,
            ),
      subjectDeleteMarkerTtl: (json['subject_delete_marker_ttl'] as num?)
          ?.toInt(),
      mirror: json['mirror'] == null
          ? null
          : StreamSource.fromJson(json['mirror'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$StreamUpdateConfigToJson(StreamUpdateConfig instance) =>
    <String, dynamic>{
      'subjects': instance.subjects,
      'description': instance.description,
      'max_msgs_per_subject': instance.maxMsgsPerSubject,
      'max_msgs': instance.maxMsgs,
      'max_age': instance.maxAge,
      'max_bytes': instance.maxBytes,
      'max_msg_size': instance.maxMsgSize,
      'discard': _$DiscardPolicyEnumMap[instance.discard],
      'discard_new_per_subject': instance.discardNewPerSubject,
      'no_ack': instance.noAck,
      'duplicate_window': instance.duplicateWindow,
      'sources': instance.sources,
      'allow_rollup_hdrs': instance.allowRollupHdrs,
      'num_replicas': instance.numReplicas,
      'placement': instance.placement,
      'deny_delete': instance.denyDelete,
      'deny_purge': instance.denyPurge,
      'allow_direct': instance.allowDirect,
      'mirror_direct': instance.mirrorDirect,
      'republish': instance.republish,
      'metadata': instance.metadata,
      'subject_transform': instance.subjectTransform,
      'compression': _$StoreCompressionEnumMap[instance.compression],
      'consumer_limits': instance.consumerLimits,
      'subject_delete_marker_ttl': instance.subjectDeleteMarkerTtl,
      'mirror': instance.mirror,
    };

const _$DiscardPolicyEnumMap = {
  DiscardPolicy.old: 'old',
  DiscardPolicy.new_: 'new',
};

const _$StoreCompressionEnumMap = {
  StoreCompression.none: 'none',
  StoreCompression.zstd: 'zstd',
};

StreamConfig _$StreamConfigFromJson(Map<String, dynamic> json) => StreamConfig(
  name: json['name'] as String,
  subjects: (json['subjects'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  retention:
      $enumDecodeNullable(_$RetentionPolicyEnumMap, json['retention']) ??
      RetentionPolicy.limits,
  maxConsumers: (json['max_consumers'] as num?)?.toInt() ?? -1,
  maxMsgs: (json['max_msgs'] as num?)?.toInt() ?? -1,
  maxBytes: (json['max_bytes'] as num?)?.toInt() ?? -1,
  maxAge: (json['max_age'] as num?)?.toInt() ?? 0,
  maxMsgSize: (json['max_msg_size'] as num?)?.toInt() ?? -1,
  storage:
      $enumDecodeNullable(_$StorageTypeEnumMap, json['storage']) ??
      StorageType.file,
  discard: $enumDecodeNullable(_$DiscardPolicyEnumMap, json['discard']),
  numReplicas: (json['num_replicas'] as num?)?.toInt() ?? 1,
  duplicateWindow: (json['duplicate_window'] as num?)?.toInt(),
  description: json['description'] as String?,
  noAck: json['no_ack'] as bool?,
  maxMsgsPerSubject: (json['max_msgs_per_subject'] as num?)?.toInt(),
  discardNewPerSubject: json['discard_new_per_subject'] as bool?,
  sources: (json['sources'] as List<dynamic>?)
      ?.map((e) => StreamSource.fromJson(e as Map<String, dynamic>))
      .toList(),
  allowRollupHdrs: json['allow_rollup_hdrs'] as bool?,
  placement: json['placement'] == null
      ? null
      : Placement.fromJson(json['placement'] as Map<String, dynamic>),
  denyDelete: json['deny_delete'] as bool?,
  denyPurge: json['deny_purge'] as bool?,
  allowDirect: json['allow_direct'] as bool?,
  mirrorDirect: json['mirror_direct'] as bool?,
  republish: json['republish'] == null
      ? null
      : Republish.fromJson(json['republish'] as Map<String, dynamic>),
  metadata: (json['metadata'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
  subjectTransform: json['subject_transform'] == null
      ? null
      : SubjectTransformConfig.fromJson(
          json['subject_transform'] as Map<String, dynamic>,
        ),
  compression: $enumDecodeNullable(
    _$StoreCompressionEnumMap,
    json['compression'],
  ),
  consumerLimits: json['consumer_limits'] == null
      ? null
      : StreamConsumerLimits.fromJson(
          json['consumer_limits'] as Map<String, dynamic>,
        ),
  subjectDeleteMarkerTtl: (json['subject_delete_marker_ttl'] as num?)?.toInt(),
  mirror: json['mirror'] == null
      ? null
      : StreamSource.fromJson(json['mirror'] as Map<String, dynamic>),
  sealed: json['sealed'] as bool?,
  firstSeq: (json['first_seq'] as num?)?.toInt(),
  allowMsgTtl: json['allow_msg_ttl'] as bool?,
  allowMsgCounter: json['allow_msg_counter'] as bool?,
  allowMsgSchedules: json['allow_msg_schedules'] as bool?,
  allowAtomic: json['allow_atomic'] as bool?,
  persistMode: $enumDecodeNullable(_$PersistModeEnumMap, json['persist_mode']),
);

Map<String, dynamic> _$StreamConfigToJson(StreamConfig instance) =>
    <String, dynamic>{
      'subjects': instance.subjects,
      'description': instance.description,
      'max_msgs_per_subject': instance.maxMsgsPerSubject,
      'max_msgs': instance.maxMsgs,
      'max_age': instance.maxAge,
      'max_bytes': instance.maxBytes,
      'max_msg_size': instance.maxMsgSize,
      'discard': _$DiscardPolicyEnumMap[instance.discard],
      'discard_new_per_subject': instance.discardNewPerSubject,
      'no_ack': instance.noAck,
      'duplicate_window': instance.duplicateWindow,
      'sources': instance.sources,
      'allow_rollup_hdrs': instance.allowRollupHdrs,
      'num_replicas': instance.numReplicas,
      'placement': instance.placement,
      'deny_delete': instance.denyDelete,
      'deny_purge': instance.denyPurge,
      'allow_direct': instance.allowDirect,
      'mirror_direct': instance.mirrorDirect,
      'republish': instance.republish,
      'metadata': instance.metadata,
      'subject_transform': instance.subjectTransform,
      'compression': _$StoreCompressionEnumMap[instance.compression],
      'consumer_limits': instance.consumerLimits,
      'subject_delete_marker_ttl': instance.subjectDeleteMarkerTtl,
      'mirror': instance.mirror,
      'name': instance.name,
      'retention': _$RetentionPolicyEnumMap[instance.retention]!,
      'max_consumers': instance.maxConsumers,
      'storage': _$StorageTypeEnumMap[instance.storage]!,
      'sealed': instance.sealed,
      'first_seq': instance.firstSeq,
      'allow_msg_ttl': instance.allowMsgTtl,
      'allow_msg_counter': instance.allowMsgCounter,
      'allow_msg_schedules': instance.allowMsgSchedules,
      'allow_atomic': instance.allowAtomic,
      'persist_mode': _$PersistModeEnumMap[instance.persistMode],
    };

const _$RetentionPolicyEnumMap = {
  RetentionPolicy.limits: 'limits',
  RetentionPolicy.interest: 'interest',
  RetentionPolicy.workQueue: 'workqueue',
};

const _$StorageTypeEnumMap = {
  StorageType.file: 'file',
  StorageType.memory: 'memory',
};

const _$PersistModeEnumMap = {
  PersistMode.Default: 'default',
  PersistMode.file: 'file',
  PersistMode.memory: 'memory',
};

StreamInfo _$StreamInfoFromJson(Map<String, dynamic> json) => StreamInfo(
  config: StreamConfig.fromJson(json['config'] as Map<String, dynamic>),
  created: json['created'] as String,
  state: StreamState.fromJson(json['state'] as Map<String, dynamic>),
);

Map<String, dynamic> _$StreamInfoToJson(StreamInfo instance) =>
    <String, dynamic>{
      'config': instance.config,
      'created': instance.created,
      'state': instance.state,
    };

ConsumerConfig _$ConsumerConfigFromJson(Map<String, dynamic> json) =>
    ConsumerConfig(
      durableName: json['durable_name'] as String?,
      deliverSubject: json['deliver_subject'] as String?,
      deliverPolicy:
          $enumDecodeNullable(_$DeliverPolicyEnumMap, json['deliver_policy']) ??
          DeliverPolicy.all,
      optStartSeq: (json['opt_start_seq'] as num?)?.toInt(),
      optStartTime: json['opt_start_time'] as String?,
      ackPolicy:
          $enumDecodeNullable(_$AckPolicyEnumMap, json['ack_policy']) ??
          AckPolicy.explicit,
      ackWait: (json['ack_wait'] as num?)?.toInt(),
      maxDeliver: (json['max_deliver'] as num?)?.toInt(),
      filterSubject: json['filter_subject'] as String?,
      replayPolicy:
          $enumDecodeNullable(_$ReplayPolicyEnumMap, json['replay_policy']) ??
          ReplayPolicy.instant,
      sampleFreq: (json['sample_freq'] as num?)?.toInt(),
      maxAckPending: (json['max_ack_pending'] as num?)?.toInt(),
      flowControl: json['flow_control'] as bool?,
      idleHeartbeat: (json['idle_heartbeat'] as num?)?.toInt(),
      description: json['description'] as String?,
    );

Map<String, dynamic> _$ConsumerConfigToJson(ConsumerConfig instance) =>
    <String, dynamic>{
      'durable_name': instance.durableName,
      'deliver_subject': instance.deliverSubject,
      'deliver_policy': _$DeliverPolicyEnumMap[instance.deliverPolicy]!,
      'opt_start_seq': instance.optStartSeq,
      'opt_start_time': instance.optStartTime,
      'ack_policy': _$AckPolicyEnumMap[instance.ackPolicy]!,
      'ack_wait': instance.ackWait,
      'max_deliver': instance.maxDeliver,
      'filter_subject': instance.filterSubject,
      'replay_policy': _$ReplayPolicyEnumMap[instance.replayPolicy]!,
      'sample_freq': instance.sampleFreq,
      'max_ack_pending': instance.maxAckPending,
      'flow_control': instance.flowControl,
      'idle_heartbeat': instance.idleHeartbeat,
      'description': instance.description,
    };

const _$DeliverPolicyEnumMap = {
  DeliverPolicy.all: 'all',
  DeliverPolicy.last: 'last',
  DeliverPolicy.new_: 'new_',
  DeliverPolicy.byStartSequence: 'by_start_sequence',
  DeliverPolicy.byStartTime: 'by_start_time',
  DeliverPolicy.lastPerSubject: 'last_per_subject',
};

const _$AckPolicyEnumMap = {
  AckPolicy.none: 'none',
  AckPolicy.explicit: 'explicit',
  AckPolicy.all: 'all',
};

const _$ReplayPolicyEnumMap = {
  ReplayPolicy.instant: 'instant',
  ReplayPolicy.original: 'original',
};

SequenceInfo _$SequenceInfoFromJson(Map<String, dynamic> json) => SequenceInfo(
  consumerSeq: (json['consumer_seq'] as num).toInt(),
  streamSeq: (json['stream_seq'] as num).toInt(),
);

Map<String, dynamic> _$SequenceInfoToJson(SequenceInfo instance) =>
    <String, dynamic>{
      'consumer_seq': instance.consumerSeq,
      'stream_seq': instance.streamSeq,
    };

ConsumerInfo _$ConsumerInfoFromJson(Map<String, dynamic> json) => ConsumerInfo(
  streamName: json['stream_name'] as String,
  name: json['name'] as String,
  created: json['created'] as String,
  config: ConsumerConfig.fromJson(json['config'] as Map<String, dynamic>),
  numPending: (json['num_pending'] as num).toInt(),
  numRedelivered: (json['num_redelivered'] as num).toInt(),
  numWaiting: (json['num_waiting'] as num).toInt(),
  delivered: json['delivered'] == null
      ? null
      : SequenceInfo.fromJson(json['delivered'] as Map<String, dynamic>),
  ackFloor: json['ack_floor'] == null
      ? null
      : SequenceInfo.fromJson(json['ack_floor'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ConsumerInfoToJson(ConsumerInfo instance) =>
    <String, dynamic>{
      'stream_name': instance.streamName,
      'name': instance.name,
      'created': instance.created,
      'config': instance.config,
      'delivered': instance.delivered,
      'ack_floor': instance.ackFloor,
      'num_pending': instance.numPending,
      'num_redelivered': instance.numRedelivered,
      'num_waiting': instance.numWaiting,
    };

JetStreamAccountStats _$JetStreamAccountStatsFromJson(
  Map<String, dynamic> json,
) => JetStreamAccountStats(
  memory: (json['memory'] as num).toInt(),
  storage: (json['storage'] as num).toInt(),
  streams: (json['streams'] as num).toInt(),
  consumers: (json['consumers'] as num).toInt(),
);

Map<String, dynamic> _$JetStreamAccountStatsToJson(
  JetStreamAccountStats instance,
) => <String, dynamic>{
  'memory': instance.memory,
  'storage': instance.storage,
  'streams': instance.streams,
  'consumers': instance.consumers,
};

PubAck _$PubAckFromJson(Map<String, dynamic> json) => PubAck(
  stream: json['stream'] as String,
  seq: (json['seq'] as num).toInt(),
  duplicate: json['duplicate'] as bool? ?? false,
  domain: json['domain'] as String?,
);

Map<String, dynamic> _$PubAckToJson(PubAck instance) => <String, dynamic>{
  'stream': instance.stream,
  'seq': instance.seq,
  'duplicate': instance.duplicate,
  'domain': instance.domain,
};
