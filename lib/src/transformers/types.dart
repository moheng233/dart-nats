import 'package:json_annotation/json_annotation.dart';

part 'types.g.dart';

/// Server information from NATS server
@JsonSerializable(
  fieldRename: FieldRename.snake,
  includeIfNull: false,
  createToJson: true,
)
class ServerInfo {
  ServerInfo({
    this.serverId,
    this.serverName,
    this.version,
    this.proto,
    this.go,
    this.host,
    this.port,
    this.headers,
    this.maxPayload,
    this.connectUrls,
    this.tlsRequired,
    this.tlsAvailable,
    this.tlsVerify,
    this.authRequired,
    this.nonce,
    this.clientId,
    this.clientIp,
    this.cluster,
    this.lameDuckMode,
  });

  factory ServerInfo.fromJson(Map<String, dynamic> json) =>
      _$ServerInfoFromJson(json);

  Map<String, dynamic> toJson() => _$ServerInfoToJson(this);

  /// Server ID
  final String? serverId;

  /// Server name
  final String? serverName;

  /// Server version
  final String? version;

  /// Protocol version
  final int? proto;

  /// Server Go version
  final String? go;

  /// Host
  final String? host;

  /// Port
  final int? port;

  /// Headers support
  final bool? headers;

  /// Maximum payload size
  final int? maxPayload;

  /// Connect URLs
  final List<String>? connectUrls;

  /// TLS required
  final bool? tlsRequired;

  /// TLS available
  final bool? tlsAvailable;

  /// TLS verify
  final bool? tlsVerify;

  /// Authentication required
  final bool? authRequired;

  /// Nonce for authentication
  final String? nonce;

  /// Client ID
  final int? clientId;

  /// Client IP
  final String? clientIp;

  /// Cluster name
  final String? cluster;

  /// Lame duck mode (graceful shutdown)
  @JsonKey(name: 'ldm')
  final bool? lameDuckMode;
}

/// Connection options for NATS client
@JsonSerializable(
  fieldRename: FieldRename.snake,
  includeIfNull: false,
  createToJson: true,
)
class ConnectOptions {
  ConnectOptions({
    this.verbose = false,
    this.pedantic = false,
    this.authToken,
    this.jwt,
    this.nkey,
    this.sig,
    this.user,
    this.pass,
    this.tlsRequired,
    this.name = 'dart-nats',
    this.lang = 'dart',
    this.version = '0.7.0',
    this.headers = true,
    this.protocol = 1,
  });

  factory ConnectOptions.fromJson(Map<String, dynamic> json) =>
      _$ConnectOptionsFromJson(json);

  Map<String, dynamic> toJson() => _$ConnectOptionsToJson(this);

  /// Verbose mode - receive +OK for each message
  @JsonKey(defaultValue: false)
  final bool verbose;

  /// Pedantic mode - stricter protocol checking
  @JsonKey(defaultValue: false)
  final bool pedantic;

  /// Authentication token
  final String? authToken;

  /// JWT for authentication
  final String? jwt;

  /// Nkey for authentication
  final String? nkey;

  /// Signature for JWT
  final String? sig;

  /// Username
  final String? user;

  /// Password
  final String? pass;

  /// TLS required
  final bool? tlsRequired;

  /// Client name
  @JsonKey(defaultValue: 'dart-nats')
  final String name;

  /// Language
  @JsonKey(defaultValue: 'dart')
  final String lang;

  /// Version
  @JsonKey(defaultValue: '0.7.0')
  final String version;

  /// Headers support
  @JsonKey(defaultValue: true)
  final bool headers;

  /// Protocol version (1 for headers support)
  @JsonKey(defaultValue: 1)
  final int protocol;
}
