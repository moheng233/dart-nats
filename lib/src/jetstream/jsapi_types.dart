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

/// JetStream API types and constants

/// Retention policy for a stream
enum RetentionPolicy {
  /// Limits based retention (messages, bytes, age)
  limits,

  /// Interest based retention - messages are kept until all consumers have acknowledged
  interest,

  /// Work queue retention - messages are removed once acknowledged
  workQueue,
}

/// Storage type for a stream
enum StorageType {
  /// File based storage
  file,

  /// Memory based storage
  memory,
}

/// Discard policy for a stream when limits are reached
enum DiscardPolicy {
  /// Discard old messages when limits are reached
  old,

  /// Discard new messages when limits are reached
  new_,
}

/// Acknowledgment policy for a consumer
enum AckPolicy {
  /// Requires no acks for delivered messages
  none,

  /// Acks are required for each message
  explicit,

  /// Acks are sampled, 100% ack not required
  all,
}

/// Delivery policy for a consumer
enum DeliverPolicy {
  /// Start delivering from the first available message
  all,

  /// Start delivering from the last message
  last,

  /// Start delivering from a specific message sequence
  new_,

  /// Start delivering from a specific sequence number
  byStartSequence,

  /// Start delivering from a specific time
  byStartTime,

  /// Start delivering from the last message for each filtered subject
  lastPerSubject,
}

/// Replay policy controls message delivery rate
enum ReplayPolicy {
  /// Deliver messages as fast as possible
  instant,

  /// Deliver messages at original received rate
  original,
}

/// JetStream API error response
class ApiError {
  /// HTTP like error code in the 300 to 500 range
  final int code;

  /// A human friendly description of the error
  final String description;

  /// The NATS error code unique to each kind of error
  final int? errCode;

  /// Creates an API error
  ApiError({
    required this.code,
    required this.description,
    this.errCode,
  });

  /// Creates an API error from JSON
  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      code: json['code'] as int,
      description: json['description'] as String,
      errCode: json['err_code'] as int?,
    );
  }

  /// Converts the API error to JSON
  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'description': description,
      if (errCode != null) 'err_code': errCode,
    };
  }
}

/// Base API response
class ApiResponse {
  /// Response type
  final String type;
  
  /// API error if present
  final ApiError? error;

  /// Creates an API response
  ApiResponse({
    required this.type,
    this.error,
  });

  /// Creates an API response from JSON
  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      type: json['type'] as String,
      error: json['error'] != null
          ? ApiError.fromJson(json['error'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Converts the API response to JSON
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (error != null) 'error': error!.toJson(),
    };
  }
}

/// Stream state information
class StreamState {
  /// Number of messages stored in the stream
  final int messages;

  /// Total size of all messages in bytes
  final int bytes;

  /// Sequence number of the first message
  final int firstSeq;

  /// Timestamp of the first message
  final String? firstTs;

  /// Sequence number of the last message
  final int lastSeq;

  /// Timestamp of the last message
  final String? lastTs;

  /// Number of consumers
  final int consumerCount;

  /// Creates a stream state
  StreamState({
    required this.messages,
    required this.bytes,
    required this.firstSeq,
    this.firstTs,
    required this.lastSeq,
    this.lastTs,
    required this.consumerCount,
  });

  /// Creates a stream state from JSON
  factory StreamState.fromJson(Map<String, dynamic> json) {
    return StreamState(
      messages: json['messages'] as int,
      bytes: json['bytes'] as int,
      firstSeq: json['first_seq'] as int,
      firstTs: json['first_ts'] as String?,
      lastSeq: json['last_seq'] as int,
      lastTs: json['last_ts'] as String?,
      consumerCount: json['consumer_count'] as int,
    );
  }

  /// Converts the stream state to JSON
  Map<String, dynamic> toJson() {
    return {
      'messages': messages,
      'bytes': bytes,
      'first_seq': firstSeq,
      if (firstTs != null) 'first_ts': firstTs,
      'last_seq': lastSeq,
      if (lastTs != null) 'last_ts': lastTs,
      'consumer_count': consumerCount,
    };
  }
}

/// Stream configuration
class StreamConfig {
  /// A unique name for the stream
  final String name;

  /// List of subjects this stream will listen on
  final List<String>? subjects;

  /// Retention policy
  final RetentionPolicy retention;

  /// Maximum number of messages to keep (-1 for unlimited)
  final int maxConsumers;

  /// Maximum number of messages (-1 for unlimited)
  final int maxMsgs;

  /// Maximum total bytes (-1 for unlimited)
  final int maxBytes;

  /// Maximum age of messages in nanoseconds (0 for unlimited)
  final int maxAge;

  /// Maximum size of a single message (-1 for unlimited)
  final int maxMsgSize;

  /// Storage type
  final StorageType storage;

  /// Discard policy
  final DiscardPolicy? discard;

  /// Number of replicas for clustered streams
  final int numReplicas;

  /// Duplicate tracking window in nanoseconds
  final int? duplicateWindow;

  /// Description of the stream
  final String? description;

  /// No ack for published messages
  final bool? noAck;

  /// Creates a stream configuration
  StreamConfig({
    required this.name,
    this.subjects,
    this.retention = RetentionPolicy.limits,
    this.maxConsumers = -1,
    this.maxMsgs = -1,
    this.maxBytes = -1,
    this.maxAge = 0,
    this.maxMsgSize = -1,
    this.storage = StorageType.file,
    this.discard,
    this.numReplicas = 1,
    this.duplicateWindow,
    this.description,
    this.noAck,
  });

  /// Creates a stream configuration from JSON
  factory StreamConfig.fromJson(Map<String, dynamic> json) {
    return StreamConfig(
      name: json['name'] as String,
      subjects: (json['subjects'] as List<dynamic>?)?.cast<String>(),
      retention: _retentionPolicyFromString(json['retention'] as String?),
      maxConsumers: json['max_consumers'] as int? ?? -1,
      maxMsgs: json['max_msgs'] as int? ?? -1,
      maxBytes: json['max_bytes'] as int? ?? -1,
      maxAge: json['max_age'] as int? ?? 0,
      maxMsgSize: json['max_msg_size'] as int? ?? -1,
      storage: _storageTypeFromString(json['storage'] as String?),
      discard: _discardPolicyFromString(json['discard'] as String?),
      numReplicas: json['num_replicas'] as int? ?? 1,
      duplicateWindow: json['duplicate_window'] as int?,
      description: json['description'] as String?,
      noAck: json['no_ack'] as bool?,
    );
  }

  /// Converts the stream configuration to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (subjects != null) 'subjects': subjects,
      'retention': _retentionPolicyToString(retention),
      'max_consumers': maxConsumers,
      'max_msgs': maxMsgs,
      'max_bytes': maxBytes,
      'max_age': maxAge,
      'max_msg_size': maxMsgSize,
      'storage': _storageTypeToString(storage),
      if (discard != null) 'discard': _discardPolicyToString(discard!),
      'num_replicas': numReplicas,
      if (duplicateWindow != null) 'duplicate_window': duplicateWindow,
      if (description != null) 'description': description,
      if (noAck != null) 'no_ack': noAck,
    };
  }
}

/// Stream information
class StreamInfo {
  /// Stream configuration
  final StreamConfig config;

  /// ISO timestamp when the stream was created
  final String created;

  /// Current stream state
  final StreamState state;

  /// Creates stream information
  StreamInfo({
    required this.config,
    required this.created,
    required this.state,
  });

  /// Creates stream information from JSON
  factory StreamInfo.fromJson(Map<String, dynamic> json) {
    return StreamInfo(
      config: StreamConfig.fromJson(json['config'] as Map<String, dynamic>),
      created: json['created'] as String,
      state: StreamState.fromJson(json['state'] as Map<String, dynamic>),
    );
  }

  /// Converts stream information to JSON
  Map<String, dynamic> toJson() {
    return {
      'config': config.toJson(),
      'created': created,
      'state': state.toJson(),
    };
  }
}

/// Consumer configuration
class ConsumerConfig {
  /// Durable name for the consumer
  final String? durableName;

  /// Delivery subject for push consumers
  final String? deliverSubject;

  /// Deliver policy
  final DeliverPolicy deliverPolicy;

  /// Starting sequence number (for byStartSequence policy)
  final int? optStartSeq;

  /// Starting time (for byStartTime policy)
  final String? optStartTime;

  /// Acknowledgment policy
  final AckPolicy ackPolicy;

  /// Acknowledgment wait time in nanoseconds
  final int? ackWait;

  /// Maximum number of delivery attempts
  final int? maxDeliver;

  /// Filter subject
  final String? filterSubject;

  /// Replay policy
  final ReplayPolicy replayPolicy;

  /// Sample percentage
  final int? sampleFreq;

  /// Maximum number of outstanding acks
  final int? maxAckPending;

  /// Flow control
  final bool? flowControl;

  /// Idle heartbeat in nanoseconds
  final int? idleHeartbeat;

  /// Description of the consumer
  final String? description;

  /// Creates a consumer configuration
  ConsumerConfig({
    this.durableName,
    this.deliverSubject,
    this.deliverPolicy = DeliverPolicy.all,
    this.optStartSeq,
    this.optStartTime,
    this.ackPolicy = AckPolicy.explicit,
    this.ackWait,
    this.maxDeliver,
    this.filterSubject,
    this.replayPolicy = ReplayPolicy.instant,
    this.sampleFreq,
    this.maxAckPending,
    this.flowControl,
    this.idleHeartbeat,
    this.description,
  });

  /// Creates a consumer configuration from JSON
  factory ConsumerConfig.fromJson(Map<String, dynamic> json) {
    return ConsumerConfig(
      durableName: json['durable_name'] as String?,
      deliverSubject: json['deliver_subject'] as String?,
      deliverPolicy: _deliverPolicyFromString(json['deliver_policy'] as String?),
      optStartSeq: json['opt_start_seq'] as int?,
      optStartTime: json['opt_start_time'] as String?,
      ackPolicy: _ackPolicyFromString(json['ack_policy'] as String?),
      ackWait: json['ack_wait'] as int?,
      maxDeliver: json['max_deliver'] as int?,
      filterSubject: json['filter_subject'] as String?,
      replayPolicy: _replayPolicyFromString(json['replay_policy'] as String?),
      sampleFreq: json['sample_freq'] as int?,
      maxAckPending: json['max_ack_pending'] as int?,
      flowControl: json['flow_control'] as bool?,
      idleHeartbeat: json['idle_heartbeat'] as int?,
      description: json['description'] as String?,
    );
  }

  /// Converts the consumer configuration to JSON
  Map<String, dynamic> toJson() {
    return {
      if (durableName != null) 'durable_name': durableName,
      if (deliverSubject != null) 'deliver_subject': deliverSubject,
      'deliver_policy': _deliverPolicyToString(deliverPolicy),
      if (optStartSeq != null) 'opt_start_seq': optStartSeq,
      if (optStartTime != null) 'opt_start_time': optStartTime,
      'ack_policy': _ackPolicyToString(ackPolicy),
      if (ackWait != null) 'ack_wait': ackWait,
      if (maxDeliver != null) 'max_deliver': maxDeliver,
      if (filterSubject != null) 'filter_subject': filterSubject,
      'replay_policy': _replayPolicyToString(replayPolicy),
      if (sampleFreq != null) 'sample_freq': sampleFreq,
      if (maxAckPending != null) 'max_ack_pending': maxAckPending,
      if (flowControl != null) 'flow_control': flowControl,
      if (idleHeartbeat != null) 'idle_heartbeat': idleHeartbeat,
      if (description != null) 'description': description,
    };
  }
}

/// Sequence information for delivered messages
class SequenceInfo {
  /// Consumer sequence
  final int consumerSeq;

  /// Stream sequence
  final int streamSeq;

  /// Creates sequence information
  SequenceInfo({
    required this.consumerSeq,
    required this.streamSeq,
  });

  /// Creates sequence information from JSON
  factory SequenceInfo.fromJson(Map<String, dynamic> json) {
    return SequenceInfo(
      consumerSeq: json['consumer_seq'] as int,
      streamSeq: json['stream_seq'] as int,
    );
  }

  /// Converts sequence information to JSON
  Map<String, dynamic> toJson() {
    return {
      'consumer_seq': consumerSeq,
      'stream_seq': streamSeq,
    };
  }
}

/// Consumer information
class ConsumerInfo {
  /// Stream name
  final String streamName;

  /// Consumer name
  final String name;

  /// ISO timestamp when the consumer was created
  final String created;

  /// Consumer configuration
  final ConsumerConfig config;

  /// Delivered sequence information
  final SequenceInfo? delivered;

  /// Ack floor sequence information
  final SequenceInfo? ackFloor;

  /// Number of pending messages
  final int numPending;

  /// Number of redelivered messages
  final int numRedelivered;

  /// Number of waiting requests
  final int numWaiting;

  /// Creates consumer information
  ConsumerInfo({
    required this.streamName,
    required this.name,
    required this.created,
    required this.config,
    this.delivered,
    this.ackFloor,
    required this.numPending,
    required this.numRedelivered,
    required this.numWaiting,
  });

  /// Creates consumer information from JSON
  factory ConsumerInfo.fromJson(Map<String, dynamic> json) {
    return ConsumerInfo(
      streamName: json['stream_name'] as String,
      name: json['name'] as String,
      created: json['created'] as String,
      config: ConsumerConfig.fromJson(json['config'] as Map<String, dynamic>),
      delivered: json['delivered'] != null
          ? SequenceInfo.fromJson(json['delivered'] as Map<String, dynamic>)
          : null,
      ackFloor: json['ack_floor'] != null
          ? SequenceInfo.fromJson(json['ack_floor'] as Map<String, dynamic>)
          : null,
      numPending: json['num_pending'] as int,
      numRedelivered: json['num_redelivered'] as int,
      numWaiting: json['num_waiting'] as int,
    );
  }

  /// Converts consumer information to JSON
  Map<String, dynamic> toJson() {
    return {
      'stream_name': streamName,
      'name': name,
      'created': created,
      'config': config.toJson(),
      if (delivered != null) 'delivered': delivered!.toJson(),
      if (ackFloor != null) 'ack_floor': ackFloor!.toJson(),
      'num_pending': numPending,
      'num_redelivered': numRedelivered,
      'num_waiting': numWaiting,
    };
  }
}

/// JetStream account statistics
class JetStreamAccountStats {
  /// Memory storage used
  final int memory;

  /// File storage used
  final int storage;

  /// Number of streams
  final int streams;

  /// Number of consumers
  final int consumers;

  /// Creates JetStream account statistics
  JetStreamAccountStats({
    required this.memory,
    required this.storage,
    required this.streams,
    required this.consumers,
  });

  /// Creates JetStream account statistics from JSON
  factory JetStreamAccountStats.fromJson(Map<String, dynamic> json) {
    return JetStreamAccountStats(
      memory: json['memory'] as int,
      storage: json['storage'] as int,
      streams: json['streams'] as int,
      consumers: json['consumers'] as int,
    );
  }

  /// Converts JetStream account statistics to JSON
  Map<String, dynamic> toJson() {
    return {
      'memory': memory,
      'storage': storage,
      'streams': streams,
      'consumers': consumers,
    };
  }
}

// Helper functions to convert enums to/from strings

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

StorageType _storageTypeFromString(String? value) {
  switch (value) {
    case 'memory':
      return StorageType.memory;
    default:
      return StorageType.file;
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

DiscardPolicy? _discardPolicyFromString(String? value) {
  switch (value) {
    case 'new':
      return DiscardPolicy.new_;
    case 'old':
      return DiscardPolicy.old;
    default:
      return null;
  }
}

String _discardPolicyToString(DiscardPolicy policy) {
  switch (policy) {
    case DiscardPolicy.new_:
      return 'new';
    default:
      return 'old';
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

ReplayPolicy _replayPolicyFromString(String? value) {
  switch (value) {
    case 'original':
      return ReplayPolicy.original;
    default:
      return ReplayPolicy.instant;
  }
}

String _replayPolicyToString(ReplayPolicy policy) {
  switch (policy) {
    case ReplayPolicy.original:
      return 'original';
    default:
      return 'instant';
  }
}
