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

import '../message.dart';
import 'jserrors.dart';

/// JetStream message headers
class JsHeaders {
  static const String domain = 'Nats-Domain';
  static const String stream = 'Nats-Stream';
  static const String consumer = 'Nats-Consumer';
  static const String deliveredConsumerSeq = 'Nats-Delivered-Consumer-Seq';
  static const String deliveredStreamSeq = 'Nats-Delivered-Stream-Seq';
  static const String timestamp = 'Nats-Time-Stamp';
  static const String pending = 'Nats-Pending-Messages';
  static const String pendingBytes = 'Nats-Pending-Bytes';
  static const String lastConsumerSeq = 'Nats-Last-Consumer';
  static const String lastStreamSeq = 'Nats-Last-Stream';
}

/// JetStream message with metadata
class JsMsg {
  final Message _msg;
  bool _acked = false;

  JsMsg(this._msg);

  /// Get the underlying NATS message
  Message get message => _msg;

  /// Get message subject
  String? get subject => _msg.subject;

  /// Get reply subject
  String? get replyTo => _msg.replyTo;

  /// Get message data as bytes
  Uint8List get data => _msg.byte;

  /// Get message data as string
  String get stringData => _msg.string;

  /// Get message headers
  Header? get headers => _msg.header;

  /// Get stream name
  String? get stream => _msg.header?.get(JsHeaders.stream);

  /// Get consumer name
  String? get consumer => _msg.header?.get(JsHeaders.consumer);

  /// Get delivered consumer sequence
  int? get deliveredConsumerSeq {
    final val = _msg.header?.get(JsHeaders.deliveredConsumerSeq);
    return val != null ? int.tryParse(val) : null;
  }

  /// Get delivered stream sequence
  int? get deliveredStreamSeq {
    final val = _msg.header?.get(JsHeaders.deliveredStreamSeq);
    return val != null ? int.tryParse(val) : null;
  }

  /// Get timestamp
  String? get timestamp => _msg.header?.get(JsHeaders.timestamp);

  /// Get number of pending messages
  int? get pending {
    final val = _msg.header?.get(JsHeaders.pending);
    return val != null ? int.tryParse(val) : null;
  }

  /// Get number of pending bytes
  int? get pendingBytes {
    final val = _msg.header?.get(JsHeaders.pendingBytes);
    return val != null ? int.tryParse(val) : null;
  }

  /// Acknowledge the message
  void ack() {
    if (_acked) {
      throw MessageAckException('Message already acknowledged');
    }
    if (_msg.replyTo == null || _msg.replyTo!.isEmpty) {
      throw MessageAckException('No reply subject available for ack');
    }
    // Use the message's respond method instead of accessing _client
    _msg.respond(Uint8List.fromList('+ACK'.codeUnits));
    _acked = true;
  }

  /// Negatively acknowledge the message (request redelivery)
  void nak({Duration? delay}) {
    if (_acked) {
      throw MessageAckException('Message already acknowledged');
    }
    if (_msg.replyTo == null || _msg.replyTo!.isEmpty) {
      throw MessageAckException('No reply subject available for nak');
    }

    String nakMsg = '-NAK';
    if (delay != null) {
      // Convert delay to JSON format (microseconds instead of nanoseconds for compatibility)
      nakMsg = jsonEncode({'delay': delay.inMicroseconds * 1000});
    }

    _msg.respond(Uint8List.fromList(nakMsg.codeUnits));
    _acked = true;
  }

  /// Mark the message as in progress (extend ack wait)
  void inProgress() {
    if (_msg.replyTo == null || _msg.replyTo!.isEmpty) {
      throw MessageAckException('No reply subject available for in progress');
    }
    _msg.respond(Uint8List.fromList('+WIP'.codeUnits));
  }

  /// Terminate message processing (don't redeliver)
  void term() {
    if (_acked) {
      throw MessageAckException('Message already acknowledged');
    }
    if (_msg.replyTo == null || _msg.replyTo!.isEmpty) {
      throw MessageAckException('No reply subject available for term');
    }
    _msg.respond(Uint8List.fromList('+TERM'.codeUnits));
    _acked = true;
  }

  /// Check if message has been acknowledged
  bool get isAcked => _acked;

  /// Respond to message with data
  bool respond(Uint8List data) {
    return _msg.respond(data);
  }

  /// Respond to message with string
  bool respondString(String str) {
    return _msg.respondString(str);
  }
}

