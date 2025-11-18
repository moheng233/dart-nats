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

import 'package:mutex/mutex.dart';

import '../client.dart';
import '../message.dart';
import '../inbox.dart';
import 'jsapi_types.dart';
import 'jserrors.dart';
import 'jsmsg.dart';

/// JetStream options
class JetStreamOptions {
  /// Prefix for JetStream API subjects (default: '\$JS.API')
  final String apiPrefix;

  /// Request timeout
  final Duration timeout;

  /// JetStream domain
  final String? domain;

  /// Creates JetStream options
  JetStreamOptions({
    this.apiPrefix = '\$JS.API',
    this.timeout = const Duration(seconds: 5),
    this.domain,
  });
}

/// JetStream publish acknowledgment
class PubAck {
  /// Stream name
  final String stream;

  /// Sequence number in the stream
  final int seq;

  /// Whether this is a duplicate
  final bool duplicate;

  /// JetStream domain
  final String? domain;

  /// Creates a publish acknowledgment
  PubAck({
    required this.stream,
    required this.seq,
    this.duplicate = false,
    this.domain,
  });

  /// Creates a publish acknowledgment from JSON
  factory PubAck.fromJson(Map<String, dynamic> json) {
    return PubAck(
      stream: json['stream'] as String,
      seq: json['seq'] as int,
      duplicate: json['duplicate'] as bool? ?? false,
      domain: json['domain'] as String?,
    );
  }

  /// Converts the publish acknowledgment to JSON
  Map<String, dynamic> toJson() {
    return {
      'stream': stream,
      'seq': seq,
      'duplicate': duplicate,
      if (domain != null) 'domain': domain,
    };
  }
}

/// JetStream publish options
class JetStreamPublishOptions {
  /// Expected stream name
  final String? expectedStream;

  /// Expected last message ID
  final String? expectedLastMsgId;

  /// Expected last sequence
  final int? expectedLastSeq;

  /// Expected last subject sequence
  final int? expectedLastSubjectSeq;

  /// Message ID for deduplication
  final String? msgId;

  /// Custom headers to add
  final Map<String, String>? headers;

  /// Creates JetStream publish options
  JetStreamPublishOptions({
    this.expectedStream,
    this.expectedLastMsgId,
    this.expectedLastSeq,
    this.expectedLastSubjectSeq,
    this.msgId,
    this.headers,
  });
}

/// JetStream client for publishing and consuming messages
class JetStreamClient {
  final Client _nc;
  final JetStreamOptions _opts;
  
  // MuxSubscription fields for publish acknowledgments
  final _mutex = Mutex();
  String? _ackInboxPrefix;
  Subscription? _ackSub;

  /// Creates a JetStream client
  JetStreamClient(this._nc, [JetStreamOptions? opts])
      : _opts = opts ?? JetStreamOptions();

  /// Get the API prefix with domain if configured
  String get _apiPrefix {
    if (_opts.domain != null) {
      return '\$JS.${_opts.domain}.API';
    }
    return _opts.apiPrefix;
  }

  /// Initialize the MuxSubscription for publish acknowledgments if not already done
  void _initAckSubscription() {
    if (_ackInboxPrefix == null) {
      // Create a unique prefix for this JetStream client's acknowledgments
      _ackInboxPrefix = '${_nc.inboxPrefix}.${Nuid().next()}';
      // Subscribe to all acknowledgments using a wildcard
      _ackSub = _nc.sub('$_ackInboxPrefix.>');
    }
  }

  /// Publish a message to a subject and wait for JetStream acknowledgment
  Future<PubAck> publish(
    String subject,
    Uint8List data, {
    JetStreamPublishOptions? options,
  }) async {
    // Create headers if we have publish options
    Header? header;
    if (options != null) {
      header = Header();

      if (options.msgId != null) {
        header.add('Nats-Msg-Id', options.msgId!);
      }
      if (options.expectedStream != null) {
        header.add('Nats-Expected-Stream', options.expectedStream!);
      }
      if (options.expectedLastMsgId != null) {
        header.add('Nats-Expected-Last-Msg-Id', options.expectedLastMsgId!);
      }
      if (options.expectedLastSeq != null) {
        header.add('Nats-Expected-Last-Sequence',
            options.expectedLastSeq!.toString());
      }
      if (options.expectedLastSubjectSeq != null) {
        header.add('Nats-Expected-Last-Subject-Sequence',
            options.expectedLastSubjectSeq!.toString());
      }

      // Add custom headers
      options.headers?.forEach((key, value) {
        header!.add(key, value);
      });
    }

    // Acquire mutex to ensure thread-safe access to the MuxSubscription
    await _mutex.acquire();
    
    try {
      // Initialize the MuxSubscription if needed
      _initAckSubscription();
      
      // Generate a unique inbox for this specific publish
      final inbox = '$_ackInboxPrefix.${Nuid().next()}';
      
      // Publish with headers and reply-to
      await _nc.pub(subject, data, replyTo: inbox, header: header);
      
      // Wait for the acknowledgment on the shared subscription
      Message response;
      do {
        response = await _ackSub!.stream
            .take(1)
            .single
            .timeout(_opts.timeout, onTimeout: () {
          throw TimeoutException(
              'JetStream publish acknowledgment timeout: ${_opts.timeout}');
        });
      } while (response.subject != inbox);

      // Parse the response
      final responseData = utf8.decode(response.byte);
      final Map<String, dynamic> json = jsonDecode(responseData);

      // Check for errors
      if (json.containsKey('error')) {
        final error = ApiError.fromJson(json['error'] as Map<String, dynamic>);
        throw JetStreamApiException(error);
      }

      return PubAck.fromJson(json);
    } finally {
      _mutex.release();
    }
  }

  /// Publish a string message
  Future<PubAck> publishString(
    String subject,
    String data, {
    JetStreamPublishOptions? options,
  }) async {
    return publish(
      subject,
      Uint8List.fromList(utf8.encode(data)),
      options: options,
    );
  }

  /// Subscribe to a JetStream consumer (pull-based)
  /// This creates a subscription that can be used to fetch messages
  Future<JetStreamSubscription> pullSubscribe(
    String subject, {
    String? stream,
    String? consumer,
    ConsumerConfig? config,
  }) async {
    // If no consumer name is provided, we need to create an ephemeral consumer
    if (consumer == null && stream == null) {
      throw JetStreamException(
          'Either stream or consumer name must be provided');
    }

    // If consumer doesn't exist and config is provided, create it
    if (config != null && stream != null) {
      // This would typically create the consumer via API
      // For now, we'll assume it exists or will be created externally
    }

    return JetStreamSubscription._(
      _nc,
      subject,
      stream ?? '',
      consumer ?? '',
      this,
    );
  }

  /// Subscribe to a JetStream consumer (push-based)
  Future<Stream<JsMsg>> pushSubscribe(
    String subject, {
    String? stream,
    String? consumer,
    String? deliverSubject,
    ConsumerConfig? config,
  }) async {
    // Create a delivery subject if not provided
    final deliver = deliverSubject ?? newInbox(inboxPrefix: _nc.inboxPrefix);

    // Subscribe to the delivery subject
    final sub = _nc.sub(deliver);

    // Transform the subscription stream to JsMsg
    return sub.stream.map((msg) => JsMsg(msg));
  }

  /// Get NATS connection
  Client get nc => _nc;

  /// Get JetStream options
  JetStreamOptions get options => _opts;

  /// Dispose the JetStream client and cleanup resources
  /// This will unsubscribe from the MuxSubscription if it was created
  void dispose() {
    if (_ackSub != null) {
      _nc.unSub(_ackSub!);
      _ackSub = null;
      _ackInboxPrefix = null;
    }
  }
}

/// JetStream subscription for pull consumers
class JetStreamSubscription {
  final Client _nc;
  final String _stream;
  final String _consumer;
  final JetStreamClient _js;

  JetStreamSubscription._(
    this._nc,
    String subject,
    this._stream,
    this._consumer,
    this._js,
  );

  /// Fetch a batch of messages
  /// Returns a stream of JsMsg
  Stream<JsMsg> fetch(int batch, {Duration? timeout}) async* {
    // Construct the request subject for fetching messages
    final requestSubject =
        '${_js._apiPrefix}.CONSUMER.MSG.NEXT.$_stream.$_consumer';

    // Create the request payload
    final request = jsonEncode({
      'batch': batch,
      if (timeout != null) 'expires': timeout.inMicroseconds * 1000, // Convert to nanoseconds
    });

    // Create a subscription for responses
    final inbox = newInbox(inboxPrefix: _nc.inboxPrefix);
    final sub = _nc.sub(inbox);

    try {
      // Send the fetch request
      _nc.pub(
        requestSubject,
        Uint8List.fromList(utf8.encode(request)),
        replyTo: inbox,
      );

      // Wait for messages
      var count = 0;
      await for (final msg in sub.stream) {
        yield JsMsg(msg);
        count++;
        if (count >= batch) {
          break;
        }
      }
    } finally {
      _nc.unSub(sub);
    }
  }

  /// Consume messages continuously
  Stream<JsMsg> consume({int batch = 100}) async* {
    while (true) {
      await for (final msg in fetch(batch)) {
        yield msg;
      }
    }
  }

  /// Get the stream name
  String get stream => _stream;

  /// Get the consumer name
  String get consumer => _consumer;
}

/// Factory function to create a JetStream client
JetStreamClient jetstream(Client nc, [JetStreamOptions? opts]) {
  return JetStreamClient(nc, opts);
}
