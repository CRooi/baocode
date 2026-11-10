import 'dart:convert';
import 'dart:io';

import 'package:bao_agent/bao_agent.dart';
import 'package:baocode/kernel/claude_code/claude_code_transport.dart';
import 'package:baocode/kernel/claude_code/claude_compaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('compactionTranscript', () {
    final messages = <Map<String, Object?>>[
      {'role': 'user', 'content': 'Fix the bug'},
      {
        'role': 'assistant',
        'content': [
          {'type': 'thinking', 'thinking': 'secret'},
          {'type': 'text', 'text': 'Looking'},
          {
            'type': 'tool_use',
            'id': 't1',
            'name': 'Read',
            'input': {'file_path': '/a.dart'},
          },
        ],
      },
      {
        'role': 'user',
        'content': [
          {'type': 'tool_result', 'tool_use_id': 't1', 'content': 'x' * 5000},
        ],
      },
    ];

    test('writes each message out, without thoughts', () {
      final text = compactionTranscript(messages);
      expect(text, contains('<User>\nFix the bug\n</User>'));
      expect(text, contains('[Tool call Read: {"file_path":"/a.dart"}]'));
      expect(text, isNot(contains('secret')));
      expect(text, contains('x' * 5000));
    });

    test('cuts tool results short to fit', () {
      final text = compactionTranscript(
        messages,
        budget: 1000,
        resultLimit: 100,
      );
      expect(text, isNot(contains('x' * 101)));
      expect(text, contains('[… 4900 more characters]'));
    });
  });

  test('a compaction written is what the resumed session goes on from', () {
    final dir = Directory.systemTemp.createTempSync('compaction');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/s1.jsonl';
    final shared = {
      'sessionId': 's1',
      'cwd': '/p',
      'version': '2.1.0',
      'userType': 'external',
      'isSidechain': false,
    };
    File(path).writeAsStringSync(
      [
        {
          ...shared,
          'type': 'user',
          'uuid': 'u1',
          'parentUuid': null,
          'message': {'role': 'user', 'content': 'old question'},
        },
        {
          ...shared,
          'type': 'assistant',
          'uuid': 'a1',
          'parentUuid': 'u1',
          'message': {
            'id': 'm1',
            'role': 'assistant',
            'content': [
              {'type': 'text', 'text': 'old answer'},
            ],
          },
        },
      ].map(jsonEncode).join('\n'),
    );

    return writeCompaction(
      path,
      summary: '<analysis>notes</analysis><summary>The gist</summary>',
      auto: true,
      preTokens: 1000,
      postTokens: 10,
    ).then((_) {
      final lines = File(path)
          .readAsLinesSync()
          .map((line) => jsonDecode(line) as Map<String, Object?>)
          .toList();
      expect(lines, hasLength(4));
      expect(lines[2], containsPair('subtype', 'compact_boundary'));
      expect(lines[2], containsPair('logicalParentUuid', 'a1'));
      expect(lines[2]['compactMetadata'], {
        'trigger': 'auto',
        'preTokens': 1000,
        'postTokens': 10,
      });
      expect(lines[3], containsPair('isCompactSummary', true));
      expect(lines[3], containsPair('parentUuid', lines[2]['uuid']));
      expect(lines[3], containsPair('cwd', '/p'));

      final resumed = SessionStore.resume(
        sessionId: 's1',
        cwd: '/p',
        file: path,
        persist: false,
      ).apiMessages();
      expect(resumed, hasLength(1));
      final text = jsonEncode(resumed.single['content']);
      expect(text, contains('The gist'));
      expect(text, isNot(contains('old answer')));
      expect(text, isNot(contains('notes')));
    });
  });

  test('a launch BaoCode compacts for has the CLI\'s own off', () {
    const own = ClaudeLaunch(cwd: '/p');
    const ours = ClaudeLaunch(cwd: '/p', compactsItself: false);
    final ownEnv = own.settings['env'] as Map;
    final oursEnv = ours.settings['env'] as Map;
    expect(ownEnv.containsKey('DISABLE_AUTO_COMPACT'), isFalse);
    expect(oursEnv['DISABLE_AUTO_COMPACT'], '1');
    expect(ours.env, isNull);
  });
}
