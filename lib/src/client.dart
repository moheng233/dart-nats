import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'common.dart';
import 'inbox.dart';
import 'message.dart';
import 'nkeys.dart';
import 'subscription.dart';
import 'transport.dart';

const _inboxPrefix = '_INBOX';

class NatsClient {
  NatsClient() {
    _steamHandle();
  }

  final _ackStream = StreamController<bool>.broadcast();
  _ClientStatus _clientStatus = _ClientStatus.init;
  Transport? _transport;
  final bool _tlsRequired = false;
  bool _retry = false;

  Info _info = Info();
  Completer<void>? _pingCompleter;
  Completer<void>? _connectCompleter;

  Status _status = Status.disconnected;

  final _statusController = StreamController<Status>.broadcast();

  StreamController<Uint8List> _channelStream = StreamController();

  // 重连相关字段
  Timer? _reconnectTimer;
  late Uri? _lastConnectionUri;
  int _currentRetryCount = 0;
  int _retryInterval = 10;
  int _retryCount = 3;
  int _timeout = 5;
  bool _useExponentialBackoff = true;
  int _maxRetryInterval = 300; // 最大重连间隔5分钟

  /// accept bad certificate NOT recomend to use in production
  bool acceptBadCert = false;

  var _connectOption = ConnectOption();

  ///SecurityContext
  SecurityContext? securityContext;

  Nkeys? _nkeys;

  final _jsonDecoder = <Type, dynamic Function(String)>{};

  final _subs = <int, Subscription<dynamic>>{};

  final _backendSubs = <int, bool>{};

  final _pubBuffer = <_Pub>[];
  int _ssid = 0;

  List<int> _buffer = [];
  // final _jsonEncoder = <Type, String Function(Type)>{};

  _ReceiveState _receiveState = _ReceiveState.idle;

  String _receiveLine1 = '';

  ///default buffer action for pub
  bool defaultPubBuffer = true;

  String? _inboxSubPrefix;

  Subscription<dynamic>? _inboxSub;
  final _pendingRequests = <String, Completer<Message<dynamic>>>{};
  final _requestTimers = <String, Timer>{};

  /// true if connected
  bool get connected => _status == Status.connected;

  /// set Inbox prefix default '_INBOX'
  String get inboxPrefix => _inboxPrefix;

  /// add json encoder for type `<T>`
  // void registerJsonEncoder<T>(String Function(T) f) {
  //   if (T == dynamic) {
  //     NatsException('can not register dyname type');
  //   }
  //   _jsonEncoder[T] = f as String Function(Type);
  // }

  ///server info
  Info? get info => _info;

  /// Nkeys seed
  String? get seed => _nkeys?.seed;

  set seed(String? newseed) {
    if (newseed == null) {
      _nkeys = null;
      return;
    }
    _nkeys = Nkeys.fromSeed(newseed);
  }

  ///status of the client
  Status get status => _status;

  /// Stream status for status update
  Stream<Status> get statusStream => _statusController.stream;

  ///close connection to NATS server unsub to server but still keep subscription list at client
  Future<void> close() async {
    _cancelReconnectTimer();
    _setStatus(Status.closed);
    _backendSubs.forEach((_, s) => s = false);
    _inboxSub?.close();
    await _transport?.close();
    _transport = null;
    _inboxSub = null;
    _inboxSubPrefix = null;
    _requestTimers
      ..forEach((_, timer) => timer.cancel())
      ..clear();
    _pendingRequests
      ..forEach(
        (_, completer) =>
            completer.completeError(RequestError('connection closed')),
      )
      ..clear();
    _buffer = [];
    _clientStatus = _ClientStatus.closed;
  }

  /// Connect to NATS server
  Future<void> connect(
    Uri uri, {
    ConnectOption? connectOption,
    int timeout = 5,
    bool retry = true,
    int retryInterval = 10,
    int retryCount = 3,
    SecurityContext? securityContext,
    bool useExponentialBackoff = true,
    int maxRetryInterval = 300,
  }) async {
    // 保存连接参数用于重连
    _retry = retry;
    _retryInterval = retryInterval;
    _retryCount = retryCount;
    _timeout = timeout;
    _useExponentialBackoff = useExponentialBackoff;
    _maxRetryInterval = maxRetryInterval;

    _lastConnectionUri = uri;
    _currentRetryCount = 0;
    this.securityContext = securityContext;

    _connectCompleter = Completer();
    if (_clientStatus == _ClientStatus.used) {
      throw Exception(
        NatsException('client in use. must close before call connect'),
      );
    }
    if (status != Status.disconnected && status != Status.closed) {
      return Future.error('Error: status not disconnected and not closed');
    }
    _clientStatus = _ClientStatus.used;
    if (connectOption != null) _connectOption = connectOption;

    // 取消任何现有的重连定时器
    _cancelReconnectTimer();

    // 尝试初始连接
    await _performConnect();

    // Return the completer's future — the connection process will
    // complete this completer when the connection handshake finishes or
    // an unrecoverable error happens.
    return _connectCompleter!.future;
  }

  /// close connection and cancel all future retries
  Future<void> forceClose() async {
    _retry = false;
    _cancelReconnectTimer();
    await close();
  }

  /// get server max payload
  int? maxPayload() => _info.maxPayload;

  ///ping server current not implement pong verification
  Future<void> ping() {
    _pingCompleter = Completer();
    _add('ping');
    return _pingCompleter!.future;
  }

  ///publish by byte (Uint8List) return true if sucess sending or buffering
  ///return false if not connect
  Future<bool> pub(
    String? subject,
    Uint8List data, {
    String? replyTo,
    bool? buffer,
    Header? header,
  }) async {
    buffer ??= defaultPubBuffer;
    if (status != Status.connected) {
      if (buffer) {
        _pubBuffer.add(_Pub(subject, data, replyTo));
        return true;
      } else {
        return false;
      }
    }

    String cmd;
    final headerByte = header?.toBytes();
    if (header == null) {
      cmd = 'pub';
    } else {
      cmd = 'hpub';
    }
    cmd += ' $subject';
    if (replyTo != null) {
      cmd += ' $replyTo';
    }
    if (headerByte != null) {
      cmd += ' ${headerByte.length}  ${headerByte.length + data.length}';
      _add(cmd);
      _addByte(headerByte.toList()..addAll(data.toList()));
    } else {
      cmd += ' ${data.length}';
      _add(cmd);
      _addByte(data);
    }

    if (_connectOption.verbose ?? false) {
      final ack = await _ackStream.stream.first;
      return ack;
    }
    return true;
  }

  ///publish by string
  Future<bool> pubString(
    String subject,
    String str, {
    String? replyTo,
    bool buffer = true,
    Header? header,
  }) async {
    return pub(
      subject,
      Uint8List.fromList(utf8.encode(str)),
      replyTo: replyTo,
      buffer: buffer,
    );
  }

  /// add json decoder for type `<T>`
  void registerJsonDecoder<T>(T Function(String) f) {
    if (T == dynamic) {
      NatsException('can not register dyname type');
    }
    _jsonDecoder[T] = f;
  }

  /// Request will send a request payload and deliver the response message,
  /// TimeoutException on timeout.
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   await client.request('service', Uint8List.fromList('request'.codeUnits),
  ///       timeout: Duration(seconds: 2));
  /// } on TimeoutException {
  ///   timeout = true;
  /// }
  /// ```
  Future<Message<T>> request<T extends dynamic>(
    String subj,
    Uint8List data, {
    Duration timeout = const Duration(seconds: 2),
    T Function(String)? jsonDecoder,
    Header? header,
  }) async {
    if (!connected) {
      throw NatsException('request error: client not connected');
    }
    //get registered json decoder
    if (T != dynamic && jsonDecoder == null) {
      jsonDecoder = _getJsonDecoder();
    }

    if (_inboxSubPrefix == null) {
      _inboxSubPrefix = '$inboxPrefix.${Nuid().next()}';
      _inboxSub = sub<dynamic>('${_inboxSubPrefix!}.>');
    }
    final inbox = '${_inboxSubPrefix!}.${Nuid().next()}';

    final completer = Completer<Message<dynamic>>();
    _pendingRequests[inbox] = completer;

    final timer = Timer(timeout, () {
      _pendingRequests.remove(inbox);
      _requestTimers.remove(inbox);
      completer.completeError(TimeoutException('request time > $timeout'));
    });
    _requestTimers[inbox] = timer;

    unawaited(pub(subj, data, replyTo: inbox, header: header));

    final resp = await completer.future;
    final msg = Message<T>(
      resp.subject,
      resp.sid,
      resp.byte,
      this,
      replyTo: resp.replyTo,
      header: resp.header,
      jsonDecoder: jsonDecoder,
    );
    return msg;
  }

  /// requestString() helper to request()
  Future<Message<T>> requestString<T extends dynamic>(
    String subj,
    String data, {
    Duration timeout = const Duration(seconds: 2),
    T Function(String)? jsonDecoder,
    Header? header,
  }) {
    return request<T>(
      subj,
      Uint8List.fromList(data.codeUnits),
      timeout: timeout,
      jsonDecoder: jsonDecoder,
      header: header,
    );
  }

  ///subscribe to subject option with queuegroup
  Subscription<T> sub<T extends dynamic>(
    String subject, {
    String? queueGroup,
    T Function(String)? jsonDecoder,
  }) {
    _ssid++;

    //get registered json decoder
    if (T != dynamic && jsonDecoder == null) {
      jsonDecoder = _getJsonDecoder();
    }

    final s = Subscription<T>(
      _ssid,
      subject,
      this,
      queueGroup: queueGroup,
      jsonDecoder: jsonDecoder,
    );
    _subs[_ssid] = s;
    if (status == Status.connected) {
      _sub(subject, _ssid, queueGroup: queueGroup);
      _backendSubs[_ssid] = true;
    }
    return s;
  }

  // String Function(dynamic) _getJsonEncoder(Type T) {
  //   var c = _jsonDecoder[T];
  //   if (c == null) {
  //     throw NatsException('no encoder for type $T');
  //   }
  //   return c as String Function(dynamic);
  // }

  /// close tcp connect Only for testing
  Future<void> tcpClose() async {
    await _transport?.close();
    _setStatus(Status.disconnected);
  }

  /// discontinue tcpConnect. use connect(uri) instead
  ///Backward compatible with 0.2.x version
  Future<void> tcpConnect(
    String host, {
    int port = 4222,
    ConnectOption? connectOption,
    int timeout = 5,
    bool retry = true,
    int retryInterval = 10,
    int retryCount = 3,
    bool useExponentialBackoff = true,
    int maxRetryInterval = 300,
  }) {
    return connect(
      Uri(scheme: 'nats', host: host, port: port),
      retry: retry,
      retryInterval: retryInterval,
      retryCount: retryCount,
      timeout: timeout,
      connectOption: connectOption,
      useExponentialBackoff: useExponentialBackoff,
      maxRetryInterval: maxRetryInterval,
    );
  }

  ///unsubscribe
  Future<bool> unSub(Subscription<dynamic> s) async {
    final sid = s.sid;

    if (_subs[sid] == null) return false;
    _unSub(sid);
    _subs.remove(sid);
    await s.close();
    _backendSubs.remove(sid);
    return true;
  }

  ///unsubscribe by id
  Future<bool> unSubById(int sid) async {
    if (_subs[sid] == null) return false;
    return unSub(_subs[sid]!);
  }

  /// wait untril status
  Future<void> waitUntil(Status s) async {
    if (status == s) {
      return;
    }
    await for (final st in statusStream) {
      if (st == s) {
        break;
      }
    }
  }

  /// wait until client connected
  Future<void> waitUntilConnected() async {
    await waitUntil(Status.connected);
  }

  void _add(String str) {
    return _addByte(utf8.encode(str));
  }

  void _addByte(List<int> msg) {
    if (status == Status.closed || status == Status.disconnected) {
      return;
    }
    if (_transport != null) {
      _transport?.add(msg);
      _transport?.add(utf8.encode('\r\n'));
      return;
    }
    throw Exception(NatsException('no connection'));
  }

  void _addConnectOption(ConnectOption c) {
    _add('connect ${jsonEncode(c.toJson())}');
  }

  void _backendSubscriptAll() {
    _backendSubs.clear();
    _subs.forEach((sid, s) async {
      _sub(s.subject, sid, queueGroup: s.queueGroup);
      // s.backendSubscription = true;
      _backendSubs[sid] = true;
    });
  }

  /// 计算重连延迟时间
  Duration _calculateRetryDelay() {
    if (!_useExponentialBackoff) {
      return Duration(seconds: _retryInterval);
    }

    // 指数退避算法：base * 2^attempt，但不超过最大值
    final exponentialDelay = _retryInterval * (1 << _currentRetryCount);
    final clampedDelay = exponentialDelay > _maxRetryInterval
        ? _maxRetryInterval
        : exponentialDelay;

    return Duration(seconds: clampedDelay);
  }

  /// 取消重连定时器
  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  Future<bool> _connectUri(Uri uri, {int timeout = 5}) async {
    try {
      if (uri.scheme == '') {
        throw NatsException('No scheme in uri');
      }

      // 确保StreamController是打开的
      if (_channelStream.isClosed) {
        _channelStream = StreamController();
      }

      switch (uri.scheme) {
        case 'wss':
        case 'ws':
          try {
            final channel = WebSocketChannel.connect(uri);
            _setStatus(Status.infoHandshake);
            await _setTransport(WebSocketTransport(channel));
          } on Exception catch (_) {
            return false;
          }
          return true;
        case 'nats':
          var port = uri.port;
          if (port == 0) {
            port = 4222;
          }
          final sock = await Socket.connect(
            uri.host,
            port,
            timeout: Duration(seconds: timeout),
          );

          _setStatus(Status.infoHandshake);
          await _setTransport(SocketTransport(sock));
          return true;
        case 'tls':
          var port = uri.port;
          if (port == 0) {
            port = 4443;
          }
          final sock = await Socket.connect(
            uri.host,
            port,
            timeout: Duration(seconds: timeout),
          );

          _setStatus(Status.infoHandshake);
          // Immediately secure the socket for TLS scheme
          final secureSocket = await SecureSocket.secure(
            sock,
            context: securityContext,
            onBadCertificate: (certificate) {
              if (acceptBadCert) return true;
              return false;
            },
          );
          await _setTransport(SecureSocketTransport(secureSocket));
          return true;
        default:
          throw Exception(NatsException('schema ${uri.scheme} not support'));
      }
    } on Exception catch (_) {
      return false;
    }
  }

  void _flushPubBuffer() {
    _pubBuffer.forEach(_pub);
  }

  T Function(String) _getJsonDecoder<T>() {
    final c = _jsonDecoder[T];
    if (c == null) {
      throw NatsException('no decoder for type $T');
    }
    return c as T Function(String);
  }

  /// 执行连接尝试（包括初始连接和重连）
  Future<void> _performConnect({bool isReconnect = false}) async {
    if (isReconnect) {
      _setStatus(Status.reconnecting);
    } else {
      _setStatus(Status.connecting);
    }

    try {
      final uri = _lastConnectionUri!;
      final success = await _connectUri(uri, timeout: _timeout);

      if (success) {
        _currentRetryCount = 0; // 重置重试计数器
        if (_connectCompleter?.isCompleted == false) {
          _connectCompleter?.complete();
        }
      } else {
        _scheduleNextRetry();
      }
    } catch (error) {
      await close();
      if (_connectCompleter?.isCompleted == false) {
        _connectCompleter?.completeError(error);
      }
      _setStatus(Status.disconnected);
    }
  }

  void _processHMsg() {
    final s = _receiveLine1.split(' ');
    final subject = s[1];
    final sid = int.parse(s[2]);
    String? replyTo;
    int length;
    int headerLength;
    if (s.length == 5) {
      headerLength = int.parse(s[3]);
      length = int.parse(s[4]);
    } else {
      replyTo = s[3];
      headerLength = int.parse(s[4]);
      length = int.parse(s[5]);
    }
    if (_buffer.length < length) return;
    final header = Uint8List.fromList(_buffer.sublist(0, headerLength));
    final payload = Uint8List.fromList(_buffer.sublist(headerLength, length));
    // _buffer = _buffer.sublist(length + 2);
    if (_buffer.length > length + 2) {
      _buffer.removeRange(0, length + 2);
    } else {
      _buffer = [];
    }

    if (_subs[sid] != null) {
      final msg = Message(
        subject,
        sid,
        payload,
        this,
        replyTo: replyTo,
        header: Header.fromBytes(header),
      );
      _subs[sid]?.add(msg);
    }

    if (_pendingRequests.containsKey(subject)) {
      final completer = _pendingRequests.remove(subject);
      _requestTimers.remove(subject)?.cancel();
      completer?.complete(
        Message(
          subject,
          sid,
          payload,
          this,
          replyTo: replyTo,
          header: Header.fromBytes(header),
        ),
      );
    }
  }

  void _processMsg() {
    final s = _receiveLine1.split(' ');
    final subject = s[1];
    final sid = int.parse(s[2]);
    String? replyTo;
    int length;
    if (s.length == 4) {
      length = int.parse(s[3]);
    } else {
      replyTo = s[3];
      length = int.parse(s[4]);
    }
    if (_buffer.length < length) return;
    final payload = Uint8List.fromList(_buffer.sublist(0, length));
    // _buffer = _buffer.sublist(length + 2);
    if (_buffer.length > length + 2) {
      _buffer.removeRange(0, length + 2);
    } else {
      _buffer = [];
    }

    if (_subs[sid] != null) {
      _subs[sid]?.add(Message(subject, sid, payload, this, replyTo: replyTo));
    }

    if (_pendingRequests.containsKey(subject)) {
      final completer = _pendingRequests.remove(subject);
      _requestTimers.remove(subject)?.cancel();
      completer?.complete(
        Message(subject, sid, payload, this, replyTo: replyTo),
      );
    }
  }

  Future<void> _processOp() async {
    ///find endline
    final nextLineIndex = _buffer.indexWhere((c) {
      if (c == 13) {
        return true;
      }
      return false;
    });
    if (nextLineIndex == -1) return;
    final line = String.fromCharCodes(
      _buffer.sublist(0, nextLineIndex),
    ); // retest
    if (_buffer.length > nextLineIndex + 2) {
      _buffer.removeRange(0, nextLineIndex + 2);
    } else {
      _buffer = [];
    }

    ///decode operation
    final i = line.indexOf(' ');
    String op;
    String data;
    if (i != -1) {
      op = line.substring(0, i).trim().toLowerCase();
      data = line.substring(i).trim();
    } else {
      op = line.trim().toLowerCase();
      data = '';
    }

    ///process operation
    switch (op) {
      case 'msg':
        _receiveState = _ReceiveState.msg;
        _receiveLine1 = line;
        _processMsg();
        _receiveLine1 = '';
        _receiveState = _ReceiveState.idle;
      case 'hmsg':
        _receiveState = _ReceiveState.msg;
        _receiveLine1 = line;
        _processHMsg();
        _receiveLine1 = '';
        _receiveState = _ReceiveState.idle;
      case 'info':
        _info = Info.fromJson(jsonDecode(data) as Map<String, dynamic>);
        if (_tlsRequired && !(_info.tlsRequired ?? false)) {
          throw NatsException('require TLS but server not required');
        }

        if ((_info.tlsRequired ?? false) && _transport is SocketTransport) {
          _setStatus(Status.tlsHandshake);
          final oldSocket = (_transport! as SocketTransport).rawSocket;
          final secureSocket = await SecureSocket.secure(
            oldSocket,
            context: securityContext,
            onBadCertificate: (certificate) {
              if (acceptBadCert) return true;
              return false;
            },
          );

          await _setTransport(SecureSocketTransport(secureSocket));
        }

        await _sign();
        _addConnectOption(_connectOption);
        if (_connectOption.verbose ?? false) {
          final ack = await _ackStream.stream.first;
          if (ack) {
            _setStatus(Status.connected);
          } else {
            _setStatus(Status.disconnected);
          }
        } else {
          _setStatus(Status.connected);
        }
        if (_inboxSubPrefix == null) {
          _inboxSubPrefix = '$inboxPrefix.${Nuid().next()}';
          _inboxSub = sub<dynamic>('${_inboxSubPrefix!}.>');
        }
        _backendSubscriptAll();
        _flushPubBuffer();
        if (_connectCompleter?.isCompleted == false) {
          _connectCompleter!.complete();
        }
      case 'ping':
        if (status == Status.connected) {
          _add('pong');
        }
      case '-err':
        // _processErr(data);
        if (_connectOption.verbose ?? false) {
          _ackStream.sink.add(false);
        }
      case 'pong':
        _pingCompleter?.complete();
      case '+ok':
        //do nothing
        if (_connectOption.verbose ?? false) {
          _ackStream.sink.add(true);
        }
    }
  }

  Future<bool> _pub(_Pub p) async {
    if (p.replyTo == null) {
      _add('pub ${p.subject} ${p.data.length}');
    } else {
      _add('pub ${p.subject} ${p.replyTo} ${p.data.length}');
    }
    _addByte(p.data);
    if (_connectOption.verbose ?? false) {
      final ack = await _ackStream.stream.first;
      return ack;
    }
    return true;
  }

  /// 安排下一次重连
  void _scheduleNextRetry() {
    // 检查是否应该停止重连
    if (!_retry || (_retryCount != -1 && _currentRetryCount >= _retryCount)) {
      if (_connectCompleter?.isCompleted == false) {
        final errorMsg = _currentRetryCount >= _retryCount
            ? 'Max retry attempts exceeded'
            : 'Connection failed and retry is disabled';
        _connectCompleter?.completeError(NatsException(errorMsg));
      }
      return;
    }

    _currentRetryCount++;
    final delay = _calculateRetryDelay();

    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      unawaited(_performConnect(isReconnect: true));
    });
  }

  void _setStatus(Status newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  Future<void> _setTransport(Transport t) async {
    // cancel old transport and listen to new stream
    await _transport?.close();
    _transport = t;
    _transport?.stream.listen(
      (event) {
        if (_channelStream.isClosed) return;
        _channelStream.add(event);
      },
      onDone: () {
        _setStatus(Status.disconnected);
        // 如果启用了重连且连接不是主动关闭的，则启动重连
        if (_retry &&
            _status != Status.closed &&
            _clientStatus != _ClientStatus.closed) {
          _scheduleNextRetry();
        }
      },
      onError: (dynamic e) {
        _setStatus(Status.disconnected);
        // 如果启用了重连且连接不是主动关闭的，则启动重连
        if (_retry &&
            _status != Status.closed &&
            _clientStatus != _ClientStatus.closed) {
          _scheduleNextRetry();
        }
        if (e is Error) {
          throw e;
        }
      },
    );
  }

  Future<void> _sign() async {
    if (_info.nonce != null && _nkeys != null) {
      final sig = _nkeys?.sign(utf8.encode(_info.nonce!));

      _connectOption.sig = base64.encode(sig!);
    }
  }

  void _steamHandle() {
    _channelStream.stream.listen((d) {
      _buffer.addAll(d);

      while (_receiveState == _ReceiveState.idle && _buffer.contains(13)) {
        final n13 = _buffer.indexOf(13);
        final msgFull = String.fromCharCodes(
          _buffer.take(n13),
        ).toLowerCase().trim();
        final msgList = msgFull.split(' ');
        final msgType = msgList[0];
        //print('... process $msgType ${_buffer.length}');

        if (msgType == 'msg' || msgType == 'hmsg') {
          final len = int.parse(msgList.last);
          if (len > 0 && _buffer.length < (msgFull.length + len + 4)) {
            break; // not a full payload, go around again
          }
        }

        unawaited(_processOp());
      }
    });
  }

  void _sub(String? subject, int sid, {String? queueGroup}) {
    if (queueGroup == null) {
      _add('sub $subject $sid');
    } else {
      _add('sub $subject $queueGroup $sid');
    }
  }

  // TODO(moheng): unsub with max msgs

  void _unSub(int sid, {String? maxMsgs}) {
    if (maxMsgs == null) {
      _add('unsub $sid');
    } else {
      _add('unsub $sid $maxMsgs');
    }
  }
}

///status of the nats client
enum Status {
  /// disconnected or not connected
  disconnected,

  /// tlsHandshake
  tlsHandshake,

  /// channel layer connect wait for info connect handshake
  infoHandshake,

  ///connected to server ready
  connected,

  ///already close by close or server
  closed,

  ///automatic reconnection to server
  reconnecting,

  ///connecting by connect() method
  connecting,

  // draining_subs,
  // draining_pubs,
}

enum _ClientStatus {
  init,
  used,
  closed,
}

class _Pub {
  _Pub(this.subject, this.data, this.replyTo);
  final String? subject;
  final List<int> data;
  final String? replyTo;
}

enum _ReceiveState {
  idle, //op=msg -> msg
  msg, //newline -> idle
}
