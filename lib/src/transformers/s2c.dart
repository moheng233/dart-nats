import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../message.dart';
import 'types.dart';

typedef _TokenMatcher = ({List<int> upper, List<int> lower});

typedef _TokenRange = ({int start, int end});

enum _PendingType { payload, header }

final class NatsS2CTransformer
    extends StreamTransformerBase<Uint8List, NatsS2CPacket> {
  static const int _cr = 13;
  static const int _lf = 10;
  static const int _space = 32;
  static const int _tab = 9;

  static const _TokenMatcher _tokenPing = (
    upper: <int>[80, 73, 78, 71],
    lower: <int>[112, 105, 110, 103],
  );
  static const _TokenMatcher _tokenPong = (
    upper: <int>[80, 79, 78, 71],
    lower: <int>[112, 111, 110, 103],
  );
  static const _TokenMatcher _tokenOk = (
    upper: <int>[43, 79, 75],
    lower: <int>[43, 111, 107],
  );
  static const _TokenMatcher _tokenErr = (
    upper: <int>[45, 69, 82, 82],
    lower: <int>[45, 101, 114, 114],
  );
  static const _TokenMatcher _tokenInfo = (
    upper: <int>[73, 78, 70, 79],
    lower: <int>[105, 110, 102, 111],
  );
  static const _TokenMatcher _tokenMsg = (
    upper: <int>[77, 83, 71],
    lower: <int>[109, 115, 103],
  );
  static const _TokenMatcher _tokenHmsg = (
    upper: <int>[72, 77, 83, 71],
    lower: <int>[104, 109, 115, 103],
  );

  @override
  Stream<NatsS2CPacket> bind(Stream<Uint8List> stream) async* {
    final lineBuffer = BytesBuilder(copy: false);

    var awaitingLf = false;

    _PendingPayload? pendingPayload;
    _PendingType? pendingStep;
    Uint8List? pendingHeader;

    await for (final chunk in stream) {
      if (chunk.isEmpty) continue;

      var offset = 0;
      while (offset < chunk.length) {
        final byte = chunk[offset];
        offset++;

        if (awaitingLf) {
          if (byte == _lf) {
            awaitingLf = false;
            final line = lineBuffer.takeBytes();
            if (line.isEmpty) {
              continue;
            }
            switch (pendingStep) {
              case null:
                final result = _parseControlLine(line);
                if (result is NatsS2CPacket) {
                  yield result;
                } else if (result is _PendingPayload) {
                  pendingPayload = result;
                  if (result.headerLength > 0) {
                    pendingStep = .header;
                  } else {
                    if (result.payloadLength > 0) {
                      pendingStep = .payload;
                    } else {
                      yield pendingPayload.buildPacket(null, null);
                    }
                  }
                }
              case _PendingType.header:
                pendingStep = .payload;
                pendingHeader = line;
              case _PendingType.payload:
                pendingStep = null;

                final result = pendingPayload!.buildPacket(line, pendingHeader);
                pendingHeader = null;
                pendingPayload = null;

                yield result;
            }
            continue;
          }

          lineBuffer.addByte(_cr);
          awaitingLf = false;
          // fall through to process current byte as normal
        }

        if (byte == _cr) {
          awaitingLf = true;
          continue;
        }

        lineBuffer.addByte(byte);
      }
    }
  }

  int _firstWhitespaceIndex(Uint8List data) {
    for (var i = 0; i < data.length; i++) {
      final byte = data[i];
      if (byte == _space || byte == _tab) {
        return i;
      }
    }
    return data.length;
  }

  bool _isWhitespace(int byte) => byte == _space || byte == _tab;

  bool _matchesToken(Uint8List data, int start, int end, _TokenMatcher token) {
    final length = end - start;
    if (length != token.upper.length) return false;
    for (var i = 0; i < length; i++) {
      final byte = data[start + i];
      final upper = token.upper[i];
      final lower = token.lower[i];
      if (byte != upper && byte != lower) {
        return false;
      }
    }
    return true;
  }

  Object? _parseControlLine(Uint8List line) {
    if (line.isEmpty) return null;

    final tokenEnd = _firstWhitespaceIndex(line);
    final payloadStart = _skipWhitespace(line, tokenEnd);

    if (_matchesToken(line, 0, tokenEnd, _tokenPing)) {
      return NatsS2CPingPacket();
    }

    if (_matchesToken(line, 0, tokenEnd, _tokenPong)) {
      return NatsS2CPongPacket();
    }

    if (_matchesToken(line, 0, tokenEnd, _tokenOk)) {
      return NatsS2COkPacket();
    }

    if (_matchesToken(line, 0, tokenEnd, _tokenErr)) {
      final message = ascii.decode(line.sublist(payloadStart));
      return NatsS2CErrPacket(message.trim());
    }

    if (_matchesToken(line, 0, tokenEnd, _tokenInfo)) {
      try {
        final jsonData = utf8.decode(line.sublist(payloadStart));
        final parsed = jsonDecode(jsonData);
        if (parsed is Map<String, dynamic>) {
          return NatsS2CInfoPacket(ServerInfo.fromJson(parsed));
        }
      // ignore: avoid_catches_without_on_clauses must
      } catch (e) {
        // Invalid JSON, ignore this INFO message
      }
      return null;
    }

    if (_matchesToken(line, 0, tokenEnd, _tokenMsg)) {
      return _parseMsgOrHMsg(line, hasHeaders: false);
    }

    if (_matchesToken(line, 0, tokenEnd, _tokenHmsg)) {
      return _parseMsgOrHMsg(line, hasHeaders: true);
    }

    return null;
  }

  _PendingPayload? _parseMsgOrHMsg(Uint8List line, {required bool hasHeaders}) {
    final tokens = <_TokenRange>[];
    var seenOpEnd = false;
    var inToken = false;
    var tokenStart = 0;

    for (var index = 0; index < line.length; index++) {
      final byte = line[index];
      final whitespace = _isWhitespace(byte);

      if (!seenOpEnd) {
        if (whitespace) {
          seenOpEnd = true;
        }
        continue;
      }

      if (whitespace) {
        if (inToken) {
          tokens.add((start: tokenStart, end: index));
          inToken = false;
        }
        continue;
      }

      if (!inToken) {
        inToken = true;
        tokenStart = index;
      }
    }

    if (inToken) {
      tokens.add((start: tokenStart, end: line.length));
    }

    if (tokens.length < 3) return null;

    final subject = _tokenToString(line, tokens[0]);
    final sid = _tokenToInt(line, tokens[1]);
    if (sid == null) return null;

    if (!hasHeaders) {
      if (tokens.length == 3) {
        final length = _tokenToInt(line, tokens[2]);
        if (length == null) return null;
        return _PendingPayload.msg(
          subject: subject,
          sid: sid,
          payloadLength: length,
        );
      } else if (tokens.length >= 4) {
        final replyTo = _tokenToString(line, tokens[2]);
        final length = _tokenToInt(line, tokens[3]);
        if (length == null) return null;
        return _PendingPayload.msg(
          subject: subject,
          sid: sid,
          replyTo: replyTo,
          payloadLength: length,
        );
      }
      return null;
    }

    if (tokens.length == 4) {
      final headerLength = _tokenToInt(line, tokens[2]);
      final totalLength = _tokenToInt(line, tokens[3]);
      if (headerLength == null || totalLength == null) return null;
      return _PendingPayload.hmsg(
        subject: subject,
        sid: sid,
        headerLength: headerLength,
        totalLength: totalLength,
      );
    } else if (tokens.length >= 5) {
      final replyTo = _tokenToString(line, tokens[2]);
      final headerLength = _tokenToInt(line, tokens[3]);
      final totalLength = _tokenToInt(line, tokens[4]);
      if (headerLength == null || totalLength == null) return null;
      return _PendingPayload.hmsg(
        subject: subject,
        sid: sid,
        replyTo: replyTo,
        headerLength: headerLength,
        totalLength: totalLength,
      );
    }

    return null;
  }

  int _skipWhitespace(Uint8List data, int start) {
    var index = start;
    while (index < data.length) {
      final byte = data[index];
      if (byte != _space && byte != _tab) {
        break;
      }
      index++;
    }
    return index;
  }

  int? _tokenToInt(Uint8List data, _TokenRange range) {
    return int.tryParse(_tokenToString(data, range));
  }

  String _tokenToString(Uint8List data, _TokenRange range) {
    return ascii.decode(data.sublist(range.start, range.end));
  }
}

final class _PendingPayload {
  _PendingPayload.hmsg({
    required this.subject,
    required this.sid,
    required this.headerLength,
    required this.totalLength,
    this.replyTo,
  }) : payloadLength = totalLength - headerLength;

  _PendingPayload.msg({
    required this.subject,
    required this.sid,
    required this.payloadLength,
    this.replyTo,
  }) : headerLength = 0,
       totalLength = payloadLength;

  final String subject;
  final int sid;
  final String? replyTo;
  final int headerLength;
  final int payloadLength;
  final int totalLength;

  NatsS2CPacket buildPacket(Uint8List? payload, Uint8List? header) {
    if (headerLength == 0) {
      if (payloadLength > 0) {
        assert(
          payload != null && payload.length == payloadLength,
          'Payload length mismatch: expected $payloadLength, '
          'got ${payload?.length}',
        );
      }

      return NatsS2CMsgPacket(subject, sid, payload, replyTo: replyTo);
    } else {
      assert(
        header != null && header.length == headerLength,
        'Header length mismatch: expected $headerLength, '
        'got ${header?.length}',
      );
      return NatsS2CHMsgPacket(
        subject,
        sid,
        payload,
        replyTo: replyTo,
        headers: Header.fromBytes(header!),
      );
    }
  }
}
