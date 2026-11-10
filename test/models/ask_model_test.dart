import 'dart:io';

import 'package:baocode/models/model_provider.dart';
import 'package:baocode/models/model_providers.dart';
import 'package:baocode/models/model_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

import 'proxy/model_proxy_test.dart' show FakeUpstream;

void main() {
  late FakeUpstream upstream;

  setUp(() async {
    HttpOverrides.global = null;
    upstream = await FakeUpstream.start();
    ModelProviders.current = ModelProviders.memory(
      providers: [
        ModelProvider(
          id: 'ds',
          name: 'DeepSeek',
          protocol: ProviderProtocol.openaiChat,
          baseUrl: upstream.base,
          models: const [ProviderModel(id: 'deepseek-chat')],
        ),
      ],
    );
    await ModelProviders.current.setCompactionModel('@ds/deepseek-chat');
  });

  tearDown(() async {
    await stopModelProxy();
    await upstream.close();
    ModelProviders.current = ModelProviders.memory();
  });

  String chunk(String delta) =>
      'data: {"id":"c1","object":"chat.completion.chunk","created":1,'
      '"model":"deepseek-chat","choices":[{"index":0,"delta":'
      '{"content":"$delta"},"finish_reason":null}]}';

  test('streams the compaction model\'s answer through the proxy', () async {
    upstream.reply = (_) => (
      200,
      [
        chunk('The '),
        '',
        chunk('summary'),
        '',
        'data: {"id":"c1","object":"chat.completion.chunk","created":1,'
            '"model":"deepseek-chat","choices":[{"index":0,"delta":{},'
            '"finish_reason":"stop"}],"usage":{"prompt_tokens":50,'
            '"completion_tokens":2,"total_tokens":52}}',
        '',
        'data: [DONE]',
        '',
      ],
    );
    final pieces = <String>[];
    final answer = await askModel(
      ModelProviders.current.compaction!.model,
      system: 'Sum it up',
      messages: const [
        {'role': 'user', 'content': 'A long conversation'},
      ],
      requestClass: 'compaction',
      session: 's1',
      onText: pieces.add,
    );
    expect(answer.text, 'The summary');
    expect(pieces, ['The ', 'summary']);
    expect(answer.outputTokens, 2);
    final sent = upstream.requests.single;
    expect(sent.path, '/v1/chat/completions');
    expect((sent.body as Map)['model'], 'deepseek-chat');
    // BaoCode's own hints stay on this machine.
    expect(sent.headers.keys, isNot(contains('x-claude-code-request-class')));
    expect(sent.headers.keys, isNot(contains('x-baocode-session')));
  });

  test('an upstream error is thrown', () async {
    upstream.reply = (_) => (400, ['{"error":{"message":"too long"}}']);
    await expectLater(
      askModel(
        ModelProviders.current.compaction!.model,
        system: 'Sum it up',
        messages: const [
          {'role': 'user', 'content': 'x'},
        ],
      ),
      throwsA(isA<UpstreamException>()),
    );
  });
}
