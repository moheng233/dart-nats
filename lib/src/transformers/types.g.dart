// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'types.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServerInfo _$ServerInfoFromJson(Map<String, dynamic> json) => ServerInfo(
  serverId: json['server_id'] as String?,
  serverName: json['server_name'] as String?,
  version: json['version'] as String?,
  proto: (json['proto'] as num?)?.toInt(),
  go: json['go'] as String?,
  host: json['host'] as String?,
  port: (json['port'] as num?)?.toInt(),
  headers: json['headers'] as bool?,
  maxPayload: (json['max_payload'] as num?)?.toInt(),
  connectUrls: (json['connect_urls'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  tlsRequired: json['tls_required'] as bool?,
  tlsAvailable: json['tls_available'] as bool?,
  tlsVerify: json['tls_verify'] as bool?,
  authRequired: json['auth_required'] as bool?,
  nonce: json['nonce'] as String?,
  clientId: (json['client_id'] as num?)?.toInt(),
  clientIp: json['client_ip'] as String?,
  cluster: json['cluster'] as String?,
  lameDuckMode: json['ldm'] as bool?,
);

Map<String, dynamic> _$ServerInfoToJson(ServerInfo instance) =>
    <String, dynamic>{
      'server_id': ?instance.serverId,
      'server_name': ?instance.serverName,
      'version': ?instance.version,
      'proto': ?instance.proto,
      'go': ?instance.go,
      'host': ?instance.host,
      'port': ?instance.port,
      'headers': ?instance.headers,
      'max_payload': ?instance.maxPayload,
      'connect_urls': ?instance.connectUrls,
      'tls_required': ?instance.tlsRequired,
      'tls_available': ?instance.tlsAvailable,
      'tls_verify': ?instance.tlsVerify,
      'auth_required': ?instance.authRequired,
      'nonce': ?instance.nonce,
      'client_id': ?instance.clientId,
      'client_ip': ?instance.clientIp,
      'cluster': ?instance.cluster,
      'ldm': ?instance.lameDuckMode,
    };

ConnectOptions _$ConnectOptionsFromJson(Map<String, dynamic> json) =>
    ConnectOptions(
      verbose: json['verbose'] as bool?,
      pedantic: json['pedantic'] as bool?,
      authToken: json['auth_token'] as String?,
      jwt: json['jwt'] as String?,
      nkey: json['nkey'] as String?,
      sig: json['sig'] as String?,
      user: json['user'] as String?,
      pass: json['pass'] as String?,
      tlsRequired: json['tls_required'] as bool?,
      name: json['name'] as String?,
      lang: json['lang'] as String?,
      version: json['version'] as String?,
      headers: json['headers'] as bool?,
      protocol: (json['protocol'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ConnectOptionsToJson(ConnectOptions instance) =>
    <String, dynamic>{
      'verbose': ?instance.verbose,
      'pedantic': ?instance.pedantic,
      'auth_token': ?instance.authToken,
      'jwt': ?instance.jwt,
      'nkey': ?instance.nkey,
      'sig': ?instance.sig,
      'user': ?instance.user,
      'pass': ?instance.pass,
      'tls_required': ?instance.tlsRequired,
      'name': ?instance.name,
      'lang': ?instance.lang,
      'version': ?instance.version,
      'headers': ?instance.headers,
      'protocol': ?instance.protocol,
    };
