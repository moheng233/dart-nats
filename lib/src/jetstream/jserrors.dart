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
  final String? message;
  final ApiError? apiError;

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
  JetStreamApiException(ApiError apiError)
      : super(apiError.description, apiError: apiError);
}

/// Stream not found exception
class StreamNotFoundException extends JetStreamException {
  final String streamName;

  StreamNotFoundException(this.streamName)
      : super('Stream not found: $streamName');
}

/// Consumer not found exception
class ConsumerNotFoundException extends JetStreamException {
  final String streamName;
  final String consumerName;

  ConsumerNotFoundException(this.streamName, this.consumerName)
      : super('Consumer not found: $consumerName on stream $streamName');
}

/// Stream already exists exception
class StreamAlreadyExistsException extends JetStreamException {
  final String streamName;

  StreamAlreadyExistsException(this.streamName)
      : super('Stream already exists: $streamName');
}

/// Consumer already exists exception
class ConsumerAlreadyExistsException extends JetStreamException {
  final String streamName;
  final String consumerName;

  ConsumerAlreadyExistsException(this.streamName, this.consumerName)
      : super('Consumer already exists: $consumerName on stream $streamName');
}

/// JetStream not enabled exception
class JetStreamNotEnabledException extends JetStreamException {
  JetStreamNotEnabledException()
      : super('JetStream is not enabled on the server');
}

/// Message acknowledgment exception
class MessageAckException extends JetStreamException {
  MessageAckException(String message) : super(message);
}

/// Invalid stream configuration exception
class InvalidStreamConfigException extends JetStreamException {
  InvalidStreamConfigException(String message) : super(message);
}

/// Invalid consumer configuration exception
class InvalidConsumerConfigException extends JetStreamException {
  InvalidConsumerConfigException(String message) : super(message);
}
