// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'common.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Info _$InfoFromJson(Map<String, dynamic> json) => Info(
  serverId: json['server_id'] as String?,
  serverName: json['server_name'] as String?,
  version: json['version'] as String?,
  proto: (json['proto'] as num?)?.toInt(),
  go: json['go'] as String?,
  host: json['host'] as String?,
  port: (json['port'] as num?)?.toInt(),
  tlsRequired: json['tls_required'] as bool?,
  maxPayload: (json['max_payload'] as num?)?.toInt(),
  nonce: json['nonce'] as String?,
  clientId: (json['client_id'] as num?)?.toInt(),
);

Map<String, dynamic> _$InfoToJson(Info instance) => <String, dynamic>{
  'server_id': instance.serverId,
  'server_name': instance.serverName,
  'version': instance.version,
  'proto': instance.proto,
  'go': instance.go,
  'host': instance.host,
  'port': instance.port,
  'tls_required': instance.tlsRequired,
  'max_payload': instance.maxPayload,
  'nonce': instance.nonce,
  'client_id': instance.clientId,
};

ConnectOption _$ConnectOptionFromJson(Map<String, dynamic> json) =>
    ConnectOption(
      verbose: json['verbose'] as bool? ?? false,
      pedantic: json['pedantic'] as bool?,
      authToken: json['auth_token'] as String?,
      jwt: json['jwt'] as String?,
      nkey: json['nkey'] as String?,
      user: json['user'] as String?,
      pass: json['pass'] as String?,
      tlsRequired: json['tls_required'] as bool?,
      name: json['name'] as String?,
      lang: json['lang'] as String? ?? 'dart',
      version: json['version'] as String? ?? '0.6.0',
      headers: json['headers'] as bool? ?? true,
      protocol: (json['protocol'] as num?)?.toInt() ?? 1,
    )..sig = json['sig'] as String?;

Map<String, dynamic> _$ConnectOptionToJson(ConnectOption instance) =>
    <String, dynamic>{
      'verbose': instance.verbose,
      'pedantic': instance.pedantic,
      'tls_required': instance.tlsRequired,
      'auth_token': instance.authToken,
      'jwt': instance.jwt,
      'nkey': instance.nkey,
      'sig': instance.sig,
      'user': instance.user,
      'pass': instance.pass,
      'name': instance.name,
      'lang': instance.lang,
      'version': instance.version,
      'headers': instance.headers,
      'protocol': instance.protocol,
    };
