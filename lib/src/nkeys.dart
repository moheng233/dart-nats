// ignore_for_file: constant_identifier_names TODO

import 'dart:typed_data';

import 'package:base32/base32.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

import 'common.dart';

/// PrefixByteSeed is the version byte used for encoded NATS Seeds
const int PrefixByteSeed = 18 << 3; // Base32-encodes to 'S...'

/// PrefixBytePrivate is the version byte used for encoded NATS Private keys
const int PrefixBytePrivate = 15 << 3; // Base32-encodes to 'P...'

/// PrefixByteServer is the version byte used for encoded NATS Servers
const int PrefixByteServer = 13 << 3; // Base32-encodes to 'N...'

/// PrefixByteCluster is the version byte used for encoded NATS Clusters
const int PrefixByteCluster = 2 << 3; // Base32-encodes to 'C...'

/// PrefixByteOperator is the version byte used for encoded NATS Operators
const int PrefixByteOperator = 14 << 3; // Base32-encodes to 'O...'

/// PrefixByteAccount is the version byte used for encoded NATS Accounts
const PrefixByteAccount = 0; // Base32-encodes to 'A...'

/// PrefixByteUser is the version byte used for encoded NATS Users
const int PrefixByteUser = 20 << 3; // Base32-encodes to 'U...'

/// PrefixByteUnknown is for unknown prefixes.
const int PrefixByteUnknown = 23 << 3; // Base32-encodes to 'X...'

///Nkeys
class Nkeys {
  ///create nkeys by keypair
  Nkeys(this.prefixByte, this.keyPair) {
    if (!_checkValidPrefixByte(prefixByte)) {
      throw NkeysException('invalid prefix byte $prefixByte');
    }
  }

  /// generate new nkeys
  factory Nkeys.newNkeys(int prefixByte) {
    final kp = ed.generateKey();

    return Nkeys(prefixByte, kp);
  }

  /// new nkeys from seed
  factory Nkeys.fromSeed(String seed) {
    final raw = base32.decode(seed);

    // Need to do the reverse here to get back to internal representation.
    final b1 = raw[0] & 248; // 248 = 11111000
    final b2 = ((raw[0] & 7) << 5) | ((raw[1] & 248) >> 3); // 7 = 00000111

    if (b1 != PrefixByteSeed) {
      throw Exception(NkeysException('not seed prefix byte'));
    }
    if (_checkValidPublicPrefixByte(b2) == PrefixByteUnknown) {
      throw Exception(NkeysException('not public prefix byte'));
    }

    final rawSeed = raw.sublist(2, 34);
    final key = ed.newKeyFromSeed(rawSeed);
    final kp = ed.KeyPair(key, ed.public(key));

    return Nkeys(b2, kp);
  }

  /// Create new pair
  factory Nkeys.createPair(int prefix) {
    final kp = ed.generateKey();
    return Nkeys(prefix, kp);
  }

  /// Create new User type KeyPair
  factory Nkeys.createUser() {
    return Nkeys.createPair(PrefixByteUser);
  }

  /// Create new Account type KeyPair
  factory Nkeys.createAccount() {
    return Nkeys.createPair(PrefixByteAccount);
  }

  /// Create new Operator type KeyPair
  factory Nkeys.createOperator() {
    return Nkeys.createPair(PrefixByteOperator);
  }

  /// key pair
  final ed.KeyPair keyPair;

  /// seed string
  Uint8List get rawSeed {
    return ed.seed(keyPair.privateKey);
  }

  /// prefixByte
  final int prefixByte;

  /// get public key
  String get seed {
    return _encodeSeed(prefixByte, rawSeed);
  }

  /// get public key
  String publicKey() {
    return _encode(prefixByte, keyPair.publicKey.bytes);
  }

  /// raw public key
  List<int> rawPublicKey() {
    return keyPair.publicKey.bytes;
  }

  /// get private key
  String privateKey() {
    return _encode(PrefixBytePrivate, keyPair.privateKey.bytes);
  }

  /// get raw private key
  List<int> rawPrivateKey() {
    return keyPair.privateKey.bytes;
  }

  /// Sign message
  List<int> sign(List<int> message) {
    final msg = Uint8List.fromList(message);
    final r = List<int>.from(ed.sign(keyPair.privateKey, msg));
    return r;
  }

  /// verify
  static bool verify(String publicKey, List<int> message, List<int> signature) {
    final r = _decode(publicKey);
    final prefix = r[0][0];
    if (!_checkValidPrefixByte(prefix)) {
      throw NkeysException('Ivalid Public key');
    }

    final pub = r[1].toList();
    if (pub.length < ed.PublicKeySize) {
      throw NkeysException('Ivalid Public key');
    }
    while (pub.length > ed.PublicKeySize) {
      pub.removeLast();
    }
    return ed.verify(
      ed.PublicKey(pub),
      Uint8List.fromList(message),
      Uint8List.fromList(signature),
    );
  }

  /// decide public expect prefix
  /// throw exception if error
  static Uint8List decode(int expectPrefix, String src) {
    final res = _decode(src);
    if (res[0][0] != expectPrefix) {
      throw NkeysException('encode invalid prefix');
    }
    return res[1];
  }
}

/// return [0]=prefix [1]=byte data [2]=type if prefix is 'S' seed
List<Uint8List> _decode(String src) {
  final b = base32.decode(src).toList();
  final ret = <Uint8List>[];

  final prefix = b[0];
  if (_checkValidPrefixByte(prefix)) {
    ret.add(Uint8List.fromList([prefix]));
    b.removeAt(0);
    ret.add(Uint8List.fromList(b));
    return ret;
  }

  // Might be a seed.
  // Need to do the reverse here to get back to internal representation.
  final b1 = b[0] & 248; // 248 = 11111000
  final b2 = ((b[0] & 7) << 5) | ((b[1] & 248) >> 3); // 7 = 00000111

  if (b1 == PrefixByteSeed) {
    ret.add(Uint8List.fromList([PrefixByteSeed]));
    b
      ..removeAt(0)
      ..removeAt(0);
    ret
      ..add(Uint8List.fromList(b))
      ..add(Uint8List.fromList([b2]));
    return ret;
  }

  ret.add(Uint8List.fromList([PrefixByteUnknown]));
  b.removeAt(0);
  ret.add(Uint8List.fromList(b));
  return ret;
}

int _checkValidPublicPrefixByte(int prefix) {
  switch (prefix) {
    case PrefixByteServer:
    case PrefixByteCluster:
    case PrefixByteOperator:
    case PrefixByteAccount:
    case PrefixByteUser:
      return prefix;
  }
  return PrefixByteUnknown;
}

bool _checkValidPrefixByte(int prefix) {
  switch (prefix) {
    case PrefixByteOperator:
    case PrefixByteServer:
    case PrefixByteCluster:
    case PrefixByteAccount:
    case PrefixByteUser:
    case PrefixByteSeed:
    case PrefixBytePrivate:
      return true;
  }
  return false;
}

String _encode(int prefix, List<int> src) {
  if (!_checkValidPrefixByte(prefix)) {
    throw NkeysException('encode invalid prefix');
  }

  final raw = [
    prefix,
    ...src,
    ..._crc16([prefix, ...src]),
  ];

  final bytes = Uint8List.fromList(raw);

  return _b32Encode(bytes);
}

Uint8List _crc16(List<int> bytes) {
  // CCITT
  const POLYNOMIAL = 0x1021;
  // XMODEM
  const initValue = 0x0000;

  var crc = initValue;
  for (final byte in bytes) {
    crc ^= byte << 8;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? (crc << 1) ^ POLYNOMIAL : crc << 1;
    }
  }
  final byteData = ByteData(2)..setUint16(0, crc, Endian.little);
  return byteData.buffer.asUint8List();
}

// EncodeSeed will encode a raw key with the prefix and then seed prefix
// and crc16 and then base32 encoded.
String _encodeSeed(int public, List<int> src) {
  if (_checkValidPublicPrefixByte(public) == PrefixByteUnknown) {
    throw NkeysException('Invalid public prefix byte');
  }

  if (src.length != 32) {
    throw NkeysException('Invalid src langth');
  }

  // In order to make this human printable for both bytes, we need to do a
  // little bit manipulation to setup for base32 encoding which takes
  // 5 bits at a time.
  final b1 = PrefixByteSeed | (public >> 5);
  final b2 = (public & 31) << 3; // 31 = 00011111

  final raw = [
    b1,
    b2,
    ...src,
    ..._crc16([b1, b2, ...src]),
  ];

  return _b32Encode(raw);
}

String _b32Encode(List<int> bytes) {
  final b = Uint8List.fromList(bytes);
  final str = base32.encode(b).replaceAll(RegExp('='), '');
  return str;
}
