import 'package:json_annotation/json_annotation.dart';

part 'common.g.dart';

///NATS Server Info
@JsonSerializable(fieldRename: FieldRename.snake)
class Info {
  //todo
  //authen required
  //tls_required
  //tls_verify
  //connect_url

  ///constructure
  Info({
    this.serverId,
    this.serverName,
    this.version,
    this.proto,
    this.go,
    this.host,
    this.port,
    this.tlsRequired,
    this.maxPayload,
    this.nonce,
    this.clientId,
  });

  ///constructure from json
  factory Info.fromJson(Map<String, dynamic> json) => _$InfoFromJson(json);

  /// sever id
  String? serverId;

  /// server name
  String? serverName;

  /// server version
  String? version;

  /// protocol
  int? proto;

  /// server go version
  String? go;

  /// host
  String? host;

  /// port number
  int? port;

  /// TLS Required
  bool? tlsRequired;

  /// max payload
  int? maxPayload;

  /// nounce
  String? nonce;

  ///client id assigned by server
  int? clientId;

  ///convert to json
  Map<String, dynamic> toJson() => _$InfoToJson(this);
}

///connection option to send to server
@JsonSerializable(fieldRename: FieldRename.snake)
class ConnectOption {
  ///construcure
  ConnectOption({
    this.verbose = false,
    this.pedantic,
    this.authToken,
    this.jwt,
    this.nkey,
    this.user,
    this.pass,
    this.tlsRequired,
    this.name,
    this.lang = 'dart',
    this.version = '0.6.0',
    this.headers = true,
    this.protocol = 1,
  });

  ///constructure from json
  factory ConnectOption.fromJson(Map<String, dynamic> json) =>
      _$ConnectOptionFromJson(json);

  ///NATS server send +OK or not (default nats server is turn on)  this client will auto tuen off as after connect
  bool? verbose;

  ///
  bool? pedantic;

  /// TLS require or not //not implement yet
  bool? tlsRequired;

  /// Auehtnticatio Token
  String? authToken;

  /// JWT
  String? jwt;

  /// NKEY
  String? nkey;

  /// signature jwt.sig = sign(hash(jwt.header + jwt.body), private-key(jwt.issuer))(jwt.issuer is part of jwt.body)
  String? sig;

  /// username
  String? user;

  /// password
  String? pass;

  ///server name
  String? name;

  /// lang??
  String? lang;

  /// sever version
  String? version;

  /// headers
  bool? headers;

  ///protocol
  int? protocol;

  ///export to json
  Map<String, dynamic> toJson() => _$ConnectOptionToJson(this);
}

/// Nats Exception
class NatsException implements Exception {
  /// NatsException
  NatsException(this.message);

  /// Description of the cause of the timeout.
  final String? message;

  @override
  String toString() {
    var result = 'NatsException';
    if (message != null) result = '$result: $message';
    return result;
  }
}

/// nkeys Exception
class NkeysException implements Exception {
  /// NkeysException
  NkeysException(this.message);

  /// Description of the cause of the timeout.
  final String? message;

  @override
  String toString() {
    var result = 'NkeysException';
    if (message != null) result = '$result: $message';
    return result;
  }
}

/// Request Exception
class RequestError extends NatsException {
  /// RequestError
  RequestError(String super.message);
}
