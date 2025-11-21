import 'dart:math';
import 'dart:typed_data';

var _nuid = Nuid();

///generate inbox
String newInbox({String inboxPrefix = '_INBOX', bool secure = true}) {
  if (secure) {
    _nuid = Nuid();
  }
  return inboxPrefix + _nuid.next();
}

///nuid port from go nats
class Nuid {
  ///constructure
  Nuid() {
    randomizePrefix();
    resetSequential();
  }

  Nuid._createInstance() {
    randomizePrefix();
    resetSequential();
  }
  static const _digits =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
  static const _base = 62;
  static const _maxSeq = 839299365868340224; // base^seqLen == 62^10;
  static const _minInc = 33;
  static const _maxInc = 333;
  static const _preLen = 12;
  static const _seqLen = 10;
  static const int _totalLen = _preLen + _seqLen;

  late Uint8List _pre; // check initial
  late int _seq;
  late int _inc;

  static final Nuid _nuid = Nuid._createInstance();

  /// get instance
  static Nuid getInstance() {
    return _nuid;
  }

  ///generate next nuid
  String next() {
    _seq = _seq + _inc;
    if (_seq >= _maxSeq) {
      randomizePrefix();
      resetSequential();
    }
    final s = _seq;
    final b = List<int>.from(_pre)..addAll(Uint8List(_seqLen));
    for (int? i = _totalLen, l = s; i! > _preLen; l = l ~/ _base) {
      i -= 1;
      b[i] = _digits.codeUnits[l! % _base];
    }
    return String.fromCharCodes(b);
  }

  ///reset sequential
  void resetSequential() {
    Random();
    final rng = Random.secure();

    _seq = rng.nextInt(1 << 31) << 32 | rng.nextInt(1 << 31);
    if (_seq > _maxSeq) {
      _seq = _seq % _maxSeq;
    }
    _inc = _minInc + rng.nextInt(_maxInc - _minInc);
  }

  ///random new prefix
  void randomizePrefix() {
    _pre = Uint8List(_preLen);
    final rng = Random.secure();
    for (var i = 0; i < _preLen; i++) {
      final n = rng.nextInt(255) % _base;
      _pre[i] = _digits.codeUnits[n];
    }
  }
}
