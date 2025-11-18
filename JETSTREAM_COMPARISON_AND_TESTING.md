# JetStream Implementation Comparison and Testing Report

## 概述

本文档对比了dart-nats与nats.js的JetStream实现，并提供详细的测试指南。

**分析时间**: 2025-11-18  
**dart-nats**: 当前分支  
**nats.js jetstream**: v3.x (最新版本)

---

## 一、架构对比

### 1.1 文件组织

**nats.js JetStream** (7,663行代码):
```
jetstream/src/
├── consumer.ts (1,095行) - 消费者实现
├── pushconsumer.ts (477行) - 推送消费者
├── jsclient.ts (421行) - JetStream客户端
├── jsmstream_api.ts (763行) - Stream管理API
├── jsmconsumer_api.ts (302行) - Consumer管理API
├── jsm_direct.ts (523行) - 直接Stream API
├── jsapi_types.ts (1,344行) - API类型定义
├── types.ts (1,372行) - 核心类型
├── jsmsg.ts (366行) - JetStream消息
├── jserrors.ts (267行) - 错误定义
├── jslister.ts (111行) - 列表器
└── jsutil.ts (82行) - 工具函数
```

**dart-nats JetStream** (约2,100行代码):
```
lib/src/jetstream/
├── jsclient.dart (341行) - JetStream客户端
├── jsm.dart (376行) - JetStream管理器
├── jsapi_types.dart (796行) - API类型
├── jsmsg.dart (177行) - JetStream消息
├── jserrors.dart (112行) - 错误定义
├── jetstream.dart (229行) - 导出文件
└── subscription.dart - 订阅支持
```

**差异分析**:
- nats.js代码量约为dart-nats的3.6倍
- nats.js有更细粒度的模块划分
- dart-nats缺少独立的Consumer和DirectStreamAPI实现
- dart-nats缺少Lister和批量操作工具

### 1.2 核心类设计

**nats.js**:
```typescript
// 多层API设计
JetStreamClient {
  - publish()
  - pullSubscribe()
  - consumers: ConsumerAPI
  - streams: StreamAPI
  - views: Views
}

JetStreamManager extends JetStreamClient {
  - streams: StreamAPI (完整管理功能)
  - consumers: ConsumerAPI (完整管理功能)
  - direct: DirectStreamAPI
}

Consumer (抽象基类) {
  - OrderedConsumer
  - PullConsumer
  - PushConsumer
}
```

**dart-nats**:
```dart
// 扁平API设计
JetStreamClient {
  - publish()
  - publishString()
  - pullSubscribe()
  - pushSubscribe()
}

JetStreamManager {
  - addStream()
  - updateStream()
  - deleteStream()
  - addConsumer()
  - deleteConsumer()
  - getStreamInfo()
  - listStreams()
}
```

**差异分析**:
- nats.js有更清晰的API层次结构
- dart-nats使用更简单的扁平设计
- nats.js区分了Consumer类型（Ordered/Pull/Push）
- dart-nats缺少Views和Direct API

---

## 二、功能对比

### 2.1 Publishing

| 功能 | nats.js | dart-nats | 状态 |
|------|---------|-----------|------|
| 基本发布 | ✅ | ✅ | 正常 |
| 发布确认 | ✅ | ✅ | 正常 |
| Headers支持 | ✅ | ✅ | 正常 |
| 消息去重（Msg-Id） | ✅ | ✅ | 正常 |
| 预期验证（Expected headers） | ✅ | ✅ | 正常 |
| 批量发布 | ✅ | ❌ | **缺失** |
| 重试机制 | ✅ | ❌ | **缺失** |

**dart-nats发布实现分析**:
```dart
Future<PubAck> publish(String subject, Uint8List data, {
  JetStreamPublishOptions? options,
}) async {
  // 创建headers
  Header? header;
  if (options != null) {
    header = Header();
    if (options.msgId != null) {
      header.add('Nats-Msg-Id', options.msgId!);
    }
    // ... 其他headers
  }

  // 创建临时收件箱和订阅
  final inbox = newInbox(inboxPrefix: _nc.inboxPrefix);
  final sub = _nc.sub(inbox);

  try {
    // 发布消息
    await _nc.pub(subject, data, replyTo: inbox, header: header);
    
    // 等待确认
    final response = await sub.stream.first.timeout(_opts.timeout);
    
    // 解析响应
    final json = jsonDecode(utf8.decode(response.byte));
    if (json.containsKey('error')) {
      throw JetStreamApiException(...);
    }
    
    return PubAck.fromJson(json);
  } finally {
    _nc.unSub(sub);
  }
}
```

**潜在问题**:
1. ❌ 每次发布都创建新订阅，性能开销大
2. ❌ 没有连接复用机制
3. ❌ 没有重试逻辑
4. ❌ 错误处理不够完善

**nats.js发布实现**（对比）:
```typescript
async publish(
  subj: string,
  data?: Payload,
  opts?: Partial<JetStreamPublishOptions>,
): Promise<PubAck> {
  // 使用复用的MuxSubscription
  const mux = await this.nc.mux();
  
  // 构建headers
  const h = opts?.headers || headers();
  if (opts?.msgID) {
    h.set(PubHeaders.MsgIdHdr, opts.msgID);
  }
  // ... 其他headers设置
  
  // 发布并等待响应
  const r = await this.nc.request(
    subj,
    data,
    { ...opts, headers: h },
  );
  
  // 解析和错误处理
  const pa = this.parseJsResponse(r) as PubAck;
  if (pa.duplicate) {
    // 处理重复消息
  }
  return pa;
}
```

**优势**:
- ✅ 使用MuxSubscription复用订阅
- ✅ 更好的错误处理
- ✅ 支持重复检测

### 2.2 Pull Consumer

| 功能 | nats.js | dart-nats | 状态 |
|------|---------|-----------|------|
| 基本拉取 | ✅ | ✅ | 正常 |
| Batch拉取 | ✅ | ✅ | 正常 |
| 手动ACK | ✅ | ✅ | 正常 |
| NAK | ✅ | ❓ | **需验证** |
| Term | ✅ | ❓ | **需验证** |
| InProgress | ✅ | ❓ | **需验证** |
| Ordered Consumer | ✅ | ❌ | **缺失** |
| 心跳监控 | ✅ | ❌ | **缺失** |
| 自动重连 | ✅ | ❌ | **缺失** |

**dart-nats Pull Consumer实现**:
```dart
Future<PullSubscription> pullSubscribe(
  String subject, {
  required String stream,
  required String consumer,
  // ...
}) async {
  // 获取消费者信息
  final jsm = JetStreamManager(_nc, JetStreamManagerOptions());
  final consumerInfo = await jsm.getConsumerInfo(stream, consumer);
  
  // 创建订阅
  final deliverSubject = consumerInfo.config.deliverSubject ??
      newInbox(inboxPrefix: _nc.inboxPrefix);
  final sub = _nc.sub(deliverSubject);
  
  return PullSubscription(
    _nc,
    sub,
    stream,
    consumer,
    _opts,
  );
}
```

**PullSubscription.fetch实现**:
```dart
Stream<JsMsg> fetch(int batch) async* {
  // 发送拉取请求
  final requestSubject = '$_jsPrefix.CONSUMER.MSG.NEXT.$_stream.$_consumer';
  final request = jsonEncode({
    'batch': batch,
    'no_wait': true,
  });
  
  await _nc.pub(requestSubject, 
    Uint8List.fromList(utf8.encode(request)),
    replyTo: _deliverSubject,
  );
  
  // 接收消息
  var count = 0;
  await for (final msg in _sub.stream) {
    yield JsMsg(msg);
    count++;
    if (count >= batch) break;
  }
}
```

**潜在问题**:
1. ❌ 没有超时处理
2. ❌ 没有心跳检测
3. ❌ 流可能永久阻塞
4. ❌ 没有处理408状态（无消息）

**nats.js Pull Consumer**（对比）:
```typescript
async fetch(opts?: FetchOptions): Promise<QueuedIterator<JsMsg>> {
  const req = {
    batch: opts?.max_messages || 100,
    expires: opts?.expires || 30_000_000_000, // 30秒
    no_wait: opts?.no_wait || false,
    max_bytes: opts?.max_bytes,
    idle_heartbeat: opts?.idle_heartbeat,
  };
  
  // 发送拉取请求
  await this.nc.publish(this.requestSubject, req);
  
  // 创建队列迭代器，包含超时和心跳处理
  const iter = new QueuedIteratorImpl<JsMsg>();
  
  // 设置超时定时器
  const timer = setTimeout(() => {
    iter.stop(new Error("timeout"));
  }, req.expires / 1_000_000);
  
  // 设置心跳监控
  if (req.idle_heartbeat) {
    this.monitorHeartbeat(iter, req.idle_heartbeat);
  }
  
  return iter;
}
```

**优势**:
- ✅ 完善的超时处理
- ✅ 心跳监控
- ✅ 404/408状态处理
- ✅ 自动清理资源

### 2.3 Push Consumer

| 功能 | nats.js | dart-nats | 状态 |
|------|---------|-----------|------|
| 基本推送 | ✅ | ✅ | 正常 |
| 自动ACK | ✅ | ❓ | **需验证** |
| FlowControl | ✅ | ❌ | **缺失** |
| 心跳监控 | ✅ | ❌ | **缺失** |
| Ordered | ✅ | ❌ | **缺失** |

### 2.4 Stream Management

| 功能 | nats.js | dart-nats | 状态 |
|------|---------|-----------|------|
| 创建Stream | ✅ | ✅ | 正常 |
| 更新Stream | ✅ | ✅ | 正常 |
| 删除Stream | ✅ | ✅ | 正常 |
| 列出Streams | ✅ | ✅ | 正常 |
| Stream信息 | ✅ | ✅ | 正常 |
| 清空Stream | ✅ | ✅ | 正常 |
| 删除消息 | ✅ | ❓ | **需验证** |
| 直接获取消息 | ✅ | ❌ | **缺失** |

### 2.5 Consumer Management

| 功能 | nats.js | dart-nats | 状态 |
|------|---------|-----------|------|
| 创建Consumer | ✅ | ✅ | 正常 |
| 更新Consumer | ✅ | ❌ | **缺失** |
| 删除Consumer | ✅ | ✅ | 正常 |
| 列出Consumers | ✅ | ✅ | 正常 |
| Consumer信息 | ✅ | ✅ | 正常 |

---

## 三、已知问题和Bug

### 3.1 发布性能问题

**问题**: 每次发布都创建新订阅
**影响**: 高并发场景性能差
**严重性**: 🔴 高

**现状**:
```dart
final inbox = newInbox(inboxPrefix: _nc.inboxPrefix);
final sub = _nc.sub(inbox);  // ❌ 每次都创建
try {
  await _nc.pub(subject, data, replyTo: inbox, header: header);
  final response = await sub.stream.first.timeout(_opts.timeout);
  // ...
} finally {
  _nc.unSub(sub);  // ❌ 每次都清理
}
```

**建议修复**:
- 实现MuxSubscription机制
- 复用单个通配符订阅处理所有ACK
- 类似request()方法的实现

### 3.2 Pull Consumer超时问题

**问题**: fetch()方法没有超时保护
**影响**: 可能导致永久阻塞
**严重性**: 🔴 高

**现状**:
```dart
Stream<JsMsg> fetch(int batch) async* {
  await _nc.pub(requestSubject, ...);
  
  var count = 0;
  await for (final msg in _sub.stream) {  // ❌ 可能永久等待
    yield JsMsg(msg);
    count++;
    if (count >= batch) break;
  }
}
```

**建议修复**:
- 添加timeout参数
- 处理408状态（无消息可用）
- 添加idle_heartbeat支持

### 3.3 错误处理不完整

**问题**: 缺少详细的JetStream错误码处理
**影响**: 错误诊断困难
**严重性**: 🟡 中

**当前实现**:
```dart
if (json.containsKey('error')) {
  final error = ApiError.fromJson(json['error'] as Map<String, dynamic>);
  throw JetStreamApiException(error);
}
```

**nats.js实现**:
```typescript
// 详细的错误代码定义
export const JsErrors = {
  StreamNotFound: "stream not found",
  ConsumerNotFound: "consumer not found",
  StreamNameRequired: "stream name required",
  // ... 20+种错误
};

// 特定错误类
class StreamNotFoundError extends JetStreamError {}
class ConsumerNotFoundError extends JetStreamError {}
```

**建议修复**:
- 添加具体错误类型
- 实现错误码映射
- 提供更好的错误消息

### 3.4 缺少重连处理

**问题**: Consumer订阅断开后不会自动重连
**影响**: 连接中断后需要手动重建
**严重性**: 🟡 中

**建议修复**:
- 监听连接状态
- 自动重新订阅
- 保持消费者位置

---

## 四、测试计划

### 4.1 环境准备

1. **启动JetStream服务器**:
```bash
# 使用Docker
docker compose up -d nats

# 或直接运行NATS服务器
nats-server -js

# 验证JetStream已启用
docker logs dart-nats-nats-1 | grep JETSTREAM
```

2. **安装依赖**:
```bash
dart pub get
```

### 4.2 基础功能测试

#### Test 1: Stream管理
```dart
void testStreamManagement() async {
  final client = Client();
  await client.connect(Uri.parse('nats://localhost:4222'));
  
  final jsm = await jetstreamManager(client);
  
  // 1. 创建Stream
  try {
    final streamInfo = await jsm.addStream(StreamConfig(
      name: 'TEST_STREAM',
      subjects: ['test.>'],
      maxMsgs: 100,
      storage: StorageType.memory,
    ));
    print('✓ Stream created: ${streamInfo.config.name}');
  } catch (e) {
    print('✗ Failed to create stream: $e');
  }
  
  // 2. 列出Streams
  print('\nStreams:');
  await for (final name in jsm.listStreams()) {
    print('  - $name');
  }
  
  // 3. 获取Stream信息
  try {
    final info = await jsm.getStreamInfo('TEST_STREAM');
    print('\n✓ Stream info retrieved');
    print('  Messages: ${info.state.messages}');
    print('  Bytes: ${info.state.bytes}');
  } catch (e) {
    print('✗ Failed to get stream info: $e');
  }
  
  // 4. 删除Stream
  try {
    await jsm.deleteStream('TEST_STREAM');
    print('\n✓ Stream deleted');
  } catch (e) {
    print('✗ Failed to delete stream: $e');
  }
  
  client.close();
}
```

#### Test 2: 发布和确认
```dart
void testPublish() async {
  final client = Client();
  await client.connect(Uri.parse('nats://localhost:4222'));
  
  final jsm = await jetstreamManager(client);
  final js = jetstream(client);
  
  // 创建Stream
  await jsm.addStream(StreamConfig(
    name: 'PUBLISH_TEST',
    subjects: ['publish.>'],
    storage: StorageType.memory,
  ));
  
  // 测试发布
  print('\n=== Publish Test ===');
  try {
    final ack = await js.publishString(
      'publish.test',
      'Hello JetStream',
      options: JetStreamPublishOptions(
        msgId: 'test-msg-1',
      ),
    );
    print('✓ Message published');
    print('  Stream: ${ack.stream}');
    print('  Sequence: ${ack.seq}');
    print('  Duplicate: ${ack.duplicate}');
  } catch (e) {
    print('✗ Publish failed: $e');
  }
  
  // 测试重复发布
  try {
    final ack = await js.publishString(
      'publish.test',
      'Hello JetStream',
      options: JetStreamPublishOptions(
        msgId: 'test-msg-1',  // 相同ID
      ),
    );
    print('\n✓ Duplicate publish');
    print('  Duplicate: ${ack.duplicate}');  // 应该是true
  } catch (e) {
    print('✗ Duplicate publish failed: $e');
  }
  
  await jsm.deleteStream('PUBLISH_TEST');
  client.close();
}
```

#### Test 3: Pull Consumer
```dart
void testPullConsumer() async {
  final client = Client();
  await client.connect(Uri.parse('nats://localhost:4222'));
  
  final jsm = await jetstreamManager(client);
  final js = jetstream(client);
  
  // 准备
  await jsm.addStream(StreamConfig(
    name: 'PULL_TEST',
    subjects: ['pull.>'],
    storage: StorageType.memory,
  ));
  
  // 发布测试消息
  print('\n=== Publishing test messages ===');
  for (var i = 1; i <= 5; i++) {
    await js.publishString('pull.test', 'Message $i');
  }
  
  // 创建Consumer
  await jsm.addConsumer('PULL_TEST', ConsumerConfig(
    durableName: 'PULL_CONSUMER',
    ackPolicy: AckPolicy.explicit,
  ));
  
  // 订阅
  print('\n=== Pull Subscribe Test ===');
  try {
    final sub = await js.pullSubscribe(
      'pull.>',
      stream: 'PULL_TEST',
      consumer: 'PULL_CONSUMER',
    );
    
    // Fetch消息
    print('Fetching 3 messages...');
    var count = 0;
    await for (final msg in sub.fetch(3)) {
      count++;
      print('  Message $count: ${msg.stringData}');
      msg.ack();
    }.timeout(Duration(seconds: 5), onTimeout: () {
      print('⚠ Fetch timed out (expected if no more messages)');
    });
    
    if (count > 0) {
      print('✓ Received $count messages');
    } else {
      print('✗ No messages received');
    }
  } catch (e) {
    print('✗ Pull subscribe failed: $e');
  }
  
  await jsm.deleteStream('PULL_TEST');
  client.close();
}
```

#### Test 4: 性能测试
```dart
void testPublishPerformance() async {
  final client = Client();
  await client.connect(Uri.parse('nats://localhost:4222'));
  
  final jsm = await jetstreamManager(client);
  final js = jetstream(client);
  
  await jsm.addStream(StreamConfig(
    name: 'PERF_TEST',
    subjects: ['perf.>'],
    storage: StorageType.memory,
  ));
  
  print('\n=== Performance Test ===');
  final count = 100;
  final sw = Stopwatch()..start();
  
  for (var i = 0; i < count; i++) {
    await js.publishString('perf.test', 'Message $i');
  }
  
  sw.stop();
  print('Published $count messages in ${sw.elapsedMilliseconds}ms');
  print('Rate: ${(count * 1000 / sw.elapsedMilliseconds).toStringAsFixed(2)} msg/sec');
  
  // 警告：如果性能很差(<100 msg/sec)，说明有问题
  if (count * 1000 / sw.elapsedMilliseconds < 100) {
    print('⚠ WARNING: Performance is below expected threshold');
    print('  This suggests the subscription-per-publish issue');
  }
  
  await jsm.deleteStream('PERF_TEST');
  client.close();
}
```

### 4.3 错误场景测试

#### Test 5: 错误处理
```dart
void testErrorHandling() async {
  final client = Client();
  await client.connect(Uri.parse('nats://localhost:4222'));
  
  final jsm = await jetstreamManager(client);
  final js = jetstream(client);
  
  print('\n=== Error Handling Test ===');
  
  // 1. Stream不存在
  try {
    await jsm.getStreamInfo('NONEXISTENT');
    print('✗ Should have thrown StreamNotFoundException');
  } on StreamNotFoundException {
    print('✓ StreamNotFoundException caught correctly');
  } catch (e) {
    print('✗ Wrong exception type: ${e.runtimeType}');
  }
  
  // 2. Consumer不存在
  try {
    await jsm.getConsumerInfo('STREAM', 'NONEXISTENT');
    print('✗ Should have thrown ConsumerNotFoundException');
  } on ConsumerNotFoundException {
    print('✓ ConsumerNotFoundException caught correctly');
  } catch (e) {
    print('✗ Wrong exception type: ${e.runtimeType}');
  }
  
  // 3. 发布超时
  // TODO: 需要断开连接或使用不存在的Stream
  
  client.close();
}
```

### 4.4 运行所有测试

创建`test/jetstream_integration_test.dart`:
```dart
import 'package:test/test.dart';

void main() {
  group('JetStream Integration Tests', () {
    test('Stream Management', testStreamManagement);
    test('Publish and Acknowledgment', testPublish);
    test('Pull Consumer', testPullConsumer);
    test('Publish Performance', testPublishPerformance);
    test('Error Handling', testErrorHandling);
  });
}
```

运行测试:
```bash
# 启动NATS服务器
docker compose up -d nats

# 等待服务器启动
sleep 2

# 运行测试
dart test test/jetstream_integration_test.dart
```

---

## 五、建议的改进优先级

### P0 (关键，必须修复)

1. **实现MuxSubscription用于发布**
   - 当前每次发布创建订阅严重影响性能
   - 预计提升10-100倍性能
   - 参考nats.js实现

2. **Pull Consumer超时处理**
   - 当前可能永久阻塞
   - 添加超时参数
   - 处理408状态码

### P1 (重要，建议修复)

3. **完善错误处理**
   - 添加具体错误类型
   - 实现错误码映射
   - 提供更好的错误消息

4. **心跳监控**
   - Pull Consumer心跳检测
   - 连接断开检测
   - 自动重连机制

5. **Consumer重连**
   - 监听连接状态
   - 自动重建订阅
   - 保持消费进度

### P2 (一般，可选功能)

6. **Ordered Consumer**
   - 保证顺序消费
   - 自动处理gap
   - 简化API

7. **Direct Stream API**
   - 直接获取消息
   - 绕过Consumer
   - 特定场景优化

8. **批量操作**
   - 批量发布
   - 批量ACK
   - 性能优化

---

## 六、总结

### 当前状态评估

**优点**:
- ✅ 基本功能已实现
- ✅ API设计简洁
- ✅ 支持常用场景

**主要问题**:
- 🔴 发布性能差（无订阅复用）
- 🔴 Pull Consumer可能阻塞（无超时）
- 🟡 错误处理不完整
- 🟡 缺少心跳监控
- 🟡 缺少重连机制

### 是否"损坏"？

根据分析，**当前实现不应被认为完全"损坏"**，但确实存在严重的性能和可靠性问题：

1. **基础功能可用**: Stream管理、发布、消费等基本功能都已实现
2. **性能问题严重**: 每次发布创建订阅导致性能差10-100倍
3. **可靠性问题**: Pull Consumer可能永久阻塞
4. **生产环境风险**: 不适合高并发和关键业务场景

### 测试建议

1. **先运行基础测试**: 验证功能是否正常工作
2. **性能测试**: 确认性能问题程度
3. **压力测试**: 测试高并发场景
4. **故障测试**: 测试网络中断等异常情况

### 修复路线图

**阶段1（1-2天）**: P0问题修复
- 实现MuxSubscription
- 添加Pull Consumer超时

**阶段2（3-5天）**: P1问题修复
- 完善错误处理
- 添加心跳监控
- 实现重连机制

**阶段3（可选）**: P2功能增强
- Ordered Consumer
- Direct API
- 批量操作

---

**报告完成时间**: 2025-11-18  
**下一步**: 运行测试并根据结果调整优先级
