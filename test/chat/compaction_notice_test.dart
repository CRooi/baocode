import 'package:baocode/chat/chat_models.dart';
import 'package:baocode/chat/widgets/notice_row.dart';
import 'package:baocode/kernel/claude_code/claude_code_translator.dart';
import 'package:baocode/kernel/transcript.dart';
import 'package:baocode/l10n/l10n.dart';
import 'package:baocode/link/chat_codec.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, Object?> boundary(String uuid) => {
    'type': 'system',
    'subtype': 'compact_boundary',
    'uuid': uuid,
    'compact_metadata': {
      'trigger': 'auto',
      'pre_tokens': 97100,
      'post_tokens': 10100,
    },
  };

  test('a compaction keeps what it did and the model it was done with, '
      'not for one replayed', () {
    final transcript = Transcript();
    var seq = 0;
    final translator = ClaudeTranslator(
      emit: transcript.apply,
      nextSeq: () => ++seq,
      compactionModel: () => 'GPT-6 Luna',
    );
    Map<String, Object?> summary(String uuid) => {
      'type': 'user',
      'uuid': uuid,
      'parent_tool_use_id': null,
      'isSynthetic': true,
      'message': {'role': 'user', 'content': 'summary ' * 300},
    };
    translator
      ..translate({
        'type': 'system',
        'subtype': 'status',
        'status': 'compacting',
      })
      ..translate(boundary('live'))
      ..translate(summary('live-summary'));
    translator.replaying = true;
    translator.translate(boundary('kept'));
    final notices = [
      for (var i = 0; i < transcript.length; i++) transcript.itemAt(i),
    ].whereType<NoticeItem>().toList();
    expect(notices, hasLength(2));
    final live = notices.first.compaction!;
    expect(
      (live.auto, live.before, live.after, live.model),
      (true, 97100, 10100, 'GPT-6 Luna'),
    );
    // Timed from when it started compacting; its summary's tokens.
    expect(live.duration, isNotNull);
    expect(live.tokens, greaterThan(500));
    final kept = notices.last.compaction!;
    expect((kept.model, kept.duration, kept.tokens), (null, null, null));
    expect(notices.first.text, isNot(contains(' · ')));

    final decoded = ChatCodec.decode(ChatCodec.encode(notices.first));
    final again = (decoded! as NoticeItem).compaction!;
    expect(
      (again.auto, again.before, again.after, again.model, again.tokens),
      (true, 97100, 10100, 'GPT-6 Luna', live.tokens),
    );
    expect(again.duration!.inMilliseconds, live.duration!.inMilliseconds);
  });

  test('a time the CLI gives is taken as it is', () {
    final transcript = Transcript();
    var seq = 0;
    ClaudeTranslator(emit: transcript.apply, nextSeq: () => ++seq).translate({
      ...boundary('timed'),
      'compact_metadata': {'trigger': 'manual', 'duration_ms': 32000},
    });
    final notice = transcript.itemAt(0) as NoticeItem;
    expect(notice.compaction!.duration, const Duration(seconds: 32));
    expect(notice.compaction!.auto, isFalse);
  });

  for (final (locale, expected, time) in [
    (const Locale('zh'), '已自动压缩对话', '32 秒'),
    (const Locale('en'), 'Conversation compacted automatically', '32s'),
  ]) {
    testWidgets('shown on one line in ${locale.languageCode}', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SizedBox(
              width: 640,
              child: NoticeRow(
                item: NoticeItem(
                  NoticeKind.compaction,
                  'Conversation compacted automatically',
                  compaction: Compaction(
                    auto: true,
                    before: 97100,
                    after: 10100,
                    model: 'GPT-6 Luna',
                    duration: Duration(seconds: 32),
                    tokens: 2720,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final text = find.textContaining(expected, findRichText: true);
      expect(text, findsOneWidget);
      final shown = tester.widget<RichText>(text).text.toPlainText();
      expect(shown, contains('97K → 10K'));
      expect(shown, contains('GPT-6 Luna'));
      expect(shown, contains(time));
      expect(shown, contains('85.00 tok/s'));
      expect(shown, contains('2.72k tokens'));
      expect(shown, isNot(contains('·')));
      // One line, between the two rules.
      expect(tester.getSize(text).height, lessThan(24));
      final rules = find.byType(Divider);
      expect(
        tester.getSize(rules.first).width,
        closeTo(tester.getSize(rules.last).width, 0.5),
      );
    });
  }
}
