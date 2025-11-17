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

import 'jsapi_types.dart';

/// Base JetStream exception
class JetStreamException implements Exception {
  /// Error message
  final String? message;
  
  /// API error details
  final ApiError? apiError;

  /// Creates a JetStream exception
  JetStreamException(this.message, {this.apiError});

  @override
  String toString() {
    if (apiError != null) {
      return 'JetStreamException: ${apiError!.description} (code: ${apiError!.code}, err_code: ${apiError!.errCode})';
    }
    return 'JetStreamException: $message';
  }
}

/// JetStream API error exception
class JetStreamApiException extends JetStreamException {
  /// Creates a JetStream API exception from an API error
  JetStreamApiException(ApiError apiError)
      : super(apiError.description, apiError: apiError);
}

/// Stream not found exception
class StreamNotFoundException extends JetStreamException {
  /// The name of the stream that was not found
  final String streamName;

  /// Creates a stream not found exception
  StreamNotFoundException(this.streamName)
      : super('Stream not found: $streamName');
}

/// Consumer not found exception
class ConsumerNotFoundException extends JetStreamException {
  /// The name of the stream
  final String streamName;
  
  /// The name of the consumer that was not found
  final String consumerName;

  /// Creates a consumer not found exception
  ConsumerNotFoundException(this.streamName, this.consumerName)
      : super('Consumer not found: $consumerName on stream $streamName');
}

/// Stream already exists exception
class StreamAlreadyExistsException extends JetStreamException {
  /// The name of the stream that already exists
  final String streamName;

  /// Creates a stream already exists exception
  StreamAlreadyExistsException(this.streamName)
      : super('Stream already exists: $streamName');
}

/// Consumer already exists exception
class ConsumerAlreadyExistsException extends JetStreamException {
  /// The name of the stream
  final String streamName;
  
  /// The name of the consumer that already exists
  final String consumerName;

  /// Creates a consumer already exists exception
  ConsumerAlreadyExistsException(this.streamName, this.consumerName)
      : super('Consumer already exists: $consumerName on stream $streamName');
}

/// JetStream not enabled exception
class JetStreamNotEnabledException extends JetStreamException {
  /// Creates a JetStream not enabled exception
  JetStreamNotEnabledException()
      : super('JetStream is not enabled on the server');
}

/// Message acknowledgment exception
class MessageAckException extends JetStreamException {
  /// Creates a message acknowledgment exception
  MessageAckException(String message) : super(message);
}

/// Invalid stream configuration exception
class InvalidStreamConfigException extends JetStreamException {
  /// Creates an invalid stream configuration exception
  InvalidStreamConfigException(String message) : super(message);
}

/// Invalid consumer configuration exception
class InvalidConsumerConfigException extends JetStreamException {
  /// Creates an invalid consumer configuration exception
  InvalidConsumerConfigException(String message) : super(message);
}
