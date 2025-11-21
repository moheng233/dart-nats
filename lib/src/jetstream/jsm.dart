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
import 'jsapi_codes.dart';
import 'jsapi_types.dart';
import 'jsclient.dart';
import 'jserrors.dart';

/// JetStream manager options
class JetStreamManagerOptions extends JetStreamOptions {
  /// Creates JetStream manager options
  JetStreamManagerOptions({
    super.apiPrefix,
    super.timeout,
    super.domain,
    this.checkAPI = true,
  });

  /// Whether to check if JetStream is enabled (default: true)
  final bool checkAPI;
}

/// JetStream manager for managing streams and consumers
class JetStreamManager {
  JetStreamManager._(this._nc, this._opts);
  final NatsClient _nc;
  final JetStreamManagerOptions _opts;

  /// Get the API prefix with domain if configured
  String get _apiPrefix {
    if (_opts.domain != null) {
      return '\$JS.${_opts.domain}.API';
    }
    return _opts.apiPrefix;
  }

  /// Make a JetStream API request
  Future<Map<String, dynamic>> _request(
    String subject,
    Map<String, dynamic>? payload,
  ) async {
    final data = payload != null
        ? Uint8List.fromList(utf8.encode(jsonEncode(payload)))
        : Uint8List(0);

    final response = await _nc.request(
      subject,
      data,
      timeout: _opts.timeout,
    );

    final responseData = utf8.decode(response.byte);
    final json = jsonDecode(responseData) as Map<String, dynamic>;

    // Check for errors
    if (json.containsKey('error')) {
      final error = ApiError.fromJson(json['error'] as Map<String, dynamic>);
      throw JetStreamApiException(error);
    }

    return json;
  }

  /// Get account statistics
  Future<JetStreamAccountStats> getAccountInfo() async {
    final response = await _request('$_apiPrefix.INFO', null);
    return JetStreamAccountStats.fromJson(response);
  }

  // Stream Management

  /// Add a stream
  Future<StreamInfo> addStream(StreamConfig config) async {
    final response = await _request(
      '$_apiPrefix.STREAM.CREATE.${config.name}',
      config.toJson(),
    );
    return StreamInfo.fromJson(response);
  }

  /// Update a stream
  Future<StreamInfo> updateStream(StreamConfig config) async {
    final response = await _request(
      '$_apiPrefix.STREAM.UPDATE.${config.name}',
      config.toJson(),
    );
    return StreamInfo.fromJson(response);
  }

  /// Delete a stream
  Future<bool> deleteStream(String name) async {
    final response = await _request(
      '$_apiPrefix.STREAM.DELETE.$name',
      null,
    );
    return response['success'] as bool? ?? false;
  }

  /// Get stream info
  Future<StreamInfo> getStreamInfo(String name) async {
    try {
      final response = await _request(
        '$_apiPrefix.STREAM.INFO.$name',
        null,
      );
      return StreamInfo.fromJson(response);
    } on JetStreamApiException catch (e) {
      if (e.apiError?.errCode == JetStreamApiCodes.streamNotFound) {
        // Stream not found
        throw StreamNotFoundException(name);
      }
      rethrow;
    }
  }

  /// List streams
  Stream<String> listStreams({int offset = 0}) async* {
    var currentOffset = offset;
    while (true) {
      final response = await _request(
        '$_apiPrefix.STREAM.NAMES',
        {'offset': currentOffset},
      );

      final streams = (response['streams'] as List<dynamic>?)?.cast<String>();
      if (streams == null || streams.isEmpty) {
        break;
      }

      for (final stream in streams) {
        yield stream;
      }

      final total = response['total'] as int?;
      final limit = response['limit'] as int?;
      if (total == null || limit == null) {
        break;
      }

      currentOffset += limit;
      if (currentOffset >= total) {
        break;
      }
    }
  }

  /// Get detailed stream information for all streams
  Stream<StreamInfo> streamInfo({int offset = 0}) async* {
    var currentOffset = offset;
    while (true) {
      final response = await _request(
        '$_apiPrefix.STREAM.LIST',
        {'offset': currentOffset},
      );

      final streams = (response['streams'] as List<dynamic>?)
          ?.cast<Map<String, dynamic>>();
      if (streams == null || streams.isEmpty) {
        break;
      }

      for (final streamJson in streams) {
        yield StreamInfo.fromJson(streamJson);
      }

      final total = response['total'] as int?;
      final limit = response['limit'] as int?;
      if (total == null || limit == null) {
        break;
      }

      currentOffset += limit;
      if (currentOffset >= total) {
        break;
      }
    }
  }

  /// Find stream by subject
  Future<String?> findStreamBySubject(String subject) async {
    try {
      final response = await _request(
        '$_apiPrefix.STREAM.NAMES',
        {'subject': subject},
      );
      final streams = (response['streams'] as List<dynamic>?)?.cast<String>();
      return streams?.isNotEmpty ?? false ? streams!.first : null;
    } catch (e) {
      return null;
    }
  }

  // Consumer Management

  /// Add a consumer
  Future<ConsumerInfo> addConsumer(
    String streamName,
    ConsumerConfig config,
  ) async {
    final consumerName = config.durableName ?? '';
    final subject = consumerName.isEmpty
        ? '$_apiPrefix.CONSUMER.CREATE.$streamName'
        : '$_apiPrefix.CONSUMER.DURABLE.CREATE.$streamName.$consumerName';

    final response = await _request(
      subject,
      config.toJson(),
    );
    return ConsumerInfo.fromJson(response);
  }

  /// Update a consumer
  Future<ConsumerInfo> updateConsumer(
    String streamName,
    ConsumerConfig config,
  ) async {
    if (config.durableName == null) {
      throw InvalidConsumerConfigException(
        'Consumer must be durable to update',
      );
    }

    final response = await _request(
      '$_apiPrefix.CONSUMER.DURABLE.CREATE.$streamName.${config.durableName}',
      config.toJson(),
    );
    return ConsumerInfo.fromJson(response);
  }

  /// Delete a consumer
  Future<bool> deleteConsumer(String streamName, String consumerName) async {
    final response = await _request(
      '$_apiPrefix.CONSUMER.DELETE.$streamName.$consumerName',
      null,
    );
    return response['success'] as bool? ?? false;
  }

  /// Get consumer info
  Future<ConsumerInfo> getConsumerInfo(
    String streamName,
    String consumerName,
  ) async {
    try {
      final response = await _request(
        '$_apiPrefix.CONSUMER.INFO.$streamName.$consumerName',
        null,
      );
      return ConsumerInfo.fromJson(response);
    } on JetStreamApiException catch (e) {
      if (e.apiError?.errCode == JetStreamApiCodes.consumerNotFound) {
        // Consumer not found
        throw ConsumerNotFoundException(streamName, consumerName);
      }
      rethrow;
    }
  }

  /// List consumers for a stream
  Stream<String> listConsumers(String streamName, {int offset = 0}) async* {
    var currentOffset = offset;
    while (true) {
      final response = await _request(
        '$_apiPrefix.CONSUMER.NAMES.$streamName',
        {'offset': currentOffset},
      );

      final consumers = (response['consumers'] as List<dynamic>?)
          ?.cast<String>();
      if (consumers == null || consumers.isEmpty) {
        break;
      }

      for (final consumer in consumers) {
        yield consumer;
      }

      final total = response['total'] as int?;
      final limit = response['limit'] as int?;
      if (total == null || limit == null) {
        break;
      }

      currentOffset += limit;
      if (currentOffset >= total) {
        break;
      }
    }
  }

  /// Get detailed consumer information for all consumers
  Stream<ConsumerInfo> consumerInfo(
    String streamName, {
    int offset = 0,
  }) async* {
    var currentOffset = offset;
    while (true) {
      final response = await _request(
        '$_apiPrefix.CONSUMER.LIST.$streamName',
        {'offset': currentOffset},
      );

      final consumers = (response['consumers'] as List<dynamic>?)
          ?.cast<Map<String, dynamic>>();
      if (consumers == null || consumers.isEmpty) {
        break;
      }

      for (final consumerJson in consumers) {
        yield ConsumerInfo.fromJson(consumerJson);
      }

      final total = response['total'] as int?;
      final limit = response['limit'] as int?;
      if (total == null || limit == null) {
        break;
      }

      currentOffset += limit;
      if (currentOffset >= total) {
        break;
      }
    }
  }

  /// Purge a stream
  Future<bool> purgeStream(String name) async {
    final response = await _request(
      '$_apiPrefix.STREAM.PURGE.$name',
      null,
    );
    return response['success'] as bool? ?? false;
  }

  /// Get NATS connection
  NatsClient get nc => _nc;

  /// Get JetStream options
  JetStreamManagerOptions get options => _opts;
}

/// Factory function to create a JetStream manager
Future<JetStreamManager> jetstreamManager(
  NatsClient nc, [
  JetStreamManagerOptions? opts,
]) async {
  final options = opts ?? JetStreamManagerOptions();
  final jsm = JetStreamManager._(nc, options);

  // Check if JetStream is enabled if requested
  if (options.checkAPI) {
    try {
      await jsm.getAccountInfo();
    } catch (e) {
      throw JetStreamNotEnabledException();
    }
  }

  return jsm;
}
