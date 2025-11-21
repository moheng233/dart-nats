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

part 'jsapi_types.g.dart';

/// Retention policy for a stream
@JsonEnum(fieldRename: FieldRename.snake)
enum RetentionPolicy {
  /// Limits based retention (messages, bytes, age)
  limits,

  /// Interest based retention - messages are kept until all consumers have acknowledged
  interest,

  /// Work queue retention - messages are removed once acknowledged
  @JsonValue('workqueue')
  workQueue,
}

/// Storage type for a stream
@JsonEnum(fieldRename: FieldRename.snake)
enum StorageType {
  /// File based storage
  file,

  /// Memory based storage
  memory,
}

/// Discard policy for a stream when limits are reached
@JsonEnum(fieldRename: FieldRename.snake)
enum DiscardPolicy {
  /// Discard old messages when limits are reached
  old,

  /// Discard new messages when limits are reached
  @JsonValue('new')
  new_,
}

/// Acknowledgment policy for a consumer
@JsonEnum(fieldRename: FieldRename.snake)
enum AckPolicy {
  /// Requires no acks for delivered messages
  none,

  /// Acks are required for each message
  explicit,

  /// Acks are sampled, 100% ack not required
  all,
}

/// Delivery policy for a consumer
@JsonEnum(fieldRename: FieldRename.snake)
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
@JsonEnum(fieldRename: FieldRename.snake)
enum ReplayPolicy {
  /// Deliver messages as fast as possible
  instant,

  /// Deliver messages at original received rate
  original,
}

/// JetStream API error response
@JsonSerializable(fieldRename: FieldRename.snake)
class ApiError {
  /// Creates an API error
  ApiError({
    required this.code,
    required this.description,
    this.errCode,
  });

  /// Creates an API error from JSON
  factory ApiError.fromJson(Map<String, dynamic> json) =>
      _$ApiErrorFromJson(json);

  /// HTTP like error code in the 300 to 500 range
  final int code;

  /// A human friendly description of the error
  final String description;

  /// The NATS error code unique to each kind of error
  final int? errCode;

  /// Converts the API error to JSON
  Map<String, dynamic> toJson() => _$ApiErrorToJson(this);
}

/// Base API response
@JsonSerializable(fieldRename: FieldRename.snake)
class ApiResponse {
  /// Creates an API response
  ApiResponse({
    required this.type,
    this.error,
  });

  /// Creates an API response from JSON
  factory ApiResponse.fromJson(Map<String, dynamic> json) =>
      _$ApiResponseFromJson(json);

  /// Response type
  final String type;

  /// API error if present
  final ApiError? error;

  /// Converts the API response to JSON
  Map<String, dynamic> toJson() => _$ApiResponseToJson(this);
}

/// Stream state information
@JsonSerializable(fieldRename: FieldRename.snake)
class StreamState {
  /// Creates a stream state
  StreamState({
    required this.messages,
    required this.bytes,
    required this.firstSeq,
    required this.lastSeq,
    required this.consumerCount,
    this.firstTs,
    this.lastTs,
  });

  /// Creates a stream state from JSON
  factory StreamState.fromJson(Map<String, dynamic> json) =>
      _$StreamStateFromJson(json);

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

  /// Converts the stream state to JSON
  Map<String, dynamic> toJson() => _$StreamStateToJson(this);
}

/// Stream source configuration for mirroring or sourcing
@JsonSerializable(fieldRename: FieldRename.snake)
class StreamSource {
  /// Creates a stream source
  StreamSource({
    required this.name,
    this.optStartSeq,
    this.optStartTime,
    this.filterSubject,
  });

  /// Creates from JSON
  factory StreamSource.fromJson(Map<String, dynamic> json) =>
      _$StreamSourceFromJson(json);

  /// Name of the source stream
  final String name;

  /// Optional starting sequence
  final int? optStartSeq;

  /// Optional starting time
  final String? optStartTime;

  /// Filter subject
  final String? filterSubject;

  /// Converts to JSON
  Map<String, dynamic> toJson() => _$StreamSourceToJson(this);
}

/// Stream configuration
@JsonSerializable(fieldRename: FieldRename.snake)
class StreamConfig {
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
    this.maxMsgsPerSubject,
  });

  /// Creates a stream configuration from JSON
  factory StreamConfig.fromJson(Map<String, dynamic> json) =>
      _$StreamConfigFromJson(json);

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

  /// Per subject history (number of messages per subject to keep)
  final int? maxMsgsPerSubject;

  /// Converts the stream configuration to JSON
  Map<String, dynamic> toJson() => _$StreamConfigToJson(this);
}

/// Stream information
@JsonSerializable(fieldRename: FieldRename.snake)
class StreamInfo {
  /// Creates stream information
  StreamInfo({
    required this.config,
    required this.created,
    required this.state,
  });

  /// Creates stream information from JSON
  factory StreamInfo.fromJson(Map<String, dynamic> json) =>
      _$StreamInfoFromJson(json);

  /// Stream configuration
  final StreamConfig config;

  /// ISO timestamp when the stream was created
  final String created;

  /// Current stream state
  final StreamState state;

  /// Converts stream information to JSON
  Map<String, dynamic> toJson() => _$StreamInfoToJson(this);
}

/// Consumer configuration
@JsonSerializable(fieldRename: FieldRename.snake)
class ConsumerConfig {
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
  factory ConsumerConfig.fromJson(Map<String, dynamic> json) =>
      _$ConsumerConfigFromJson(json);

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

  /// Converts the consumer configuration to JSON
  Map<String, dynamic> toJson() => _$ConsumerConfigToJson(this);
}

/// Sequence information for delivered messages
@JsonSerializable(fieldRename: FieldRename.snake)
class SequenceInfo {
  /// Creates sequence information
  SequenceInfo({
    required this.consumerSeq,
    required this.streamSeq,
  });

  /// Creates sequence information from JSON
  factory SequenceInfo.fromJson(Map<String, dynamic> json) =>
      _$SequenceInfoFromJson(json);

  /// Consumer sequence
  final int consumerSeq;

  /// Stream sequence
  final int streamSeq;

  /// Converts sequence information to JSON
  Map<String, dynamic> toJson() => _$SequenceInfoToJson(this);
}

/// Consumer information
@JsonSerializable(fieldRename: FieldRename.snake)
class ConsumerInfo {
  /// Creates consumer information
  ConsumerInfo({
    required this.streamName,
    required this.name,
    required this.created,
    required this.config,
    required this.numPending,
    required this.numRedelivered,
    required this.numWaiting,
    this.delivered,
    this.ackFloor,
  });

  /// Creates consumer information from JSON
  factory ConsumerInfo.fromJson(Map<String, dynamic> json) =>
      _$ConsumerInfoFromJson(json);

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

  /// Converts consumer information to JSON
  Map<String, dynamic> toJson() => _$ConsumerInfoToJson(this);
}

/// JetStream account statistics
@JsonSerializable(fieldRename: FieldRename.snake)
class JetStreamAccountStats {
  /// Creates JetStream account statistics
  JetStreamAccountStats({
    required this.memory,
    required this.storage,
    required this.streams,
    required this.consumers,
  });

  /// Creates JetStream account statistics from JSON
  factory JetStreamAccountStats.fromJson(Map<String, dynamic> json) =>
      _$JetStreamAccountStatsFromJson(json);

  /// Memory storage used
  final int memory;

  /// File storage used
  final int storage;

  /// Number of streams
  final int streams;

  /// Number of consumers
  final int consumers;

  /// Converts JetStream account statistics to JSON
  Map<String, dynamic> toJson() => _$JetStreamAccountStatsToJson(this);
}

/// JetStream publish acknowledgment
@JsonSerializable(fieldRename: FieldRename.snake)
class PubAck {
  /// Creates a publish acknowledgment
  PubAck({
    required this.stream,
    required this.seq,
    this.duplicate = false,
    this.domain,
  });

  /// Creates a publish acknowledgment from JSON
  factory PubAck.fromJson(Map<String, dynamic> json) => _$PubAckFromJson(json);

  /// Stream name
  final String stream;

  /// Sequence number in the stream
  final int seq;

  /// Whether this is a duplicate
  final bool duplicate;

  /// JetStream domain
  final String? domain;

  /// Converts the publish acknowledgment to JSON
  Map<String, dynamic> toJson() => _$PubAckToJson(this);
}
