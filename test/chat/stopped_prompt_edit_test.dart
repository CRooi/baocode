import 'dart:convert';

import 'package:bao_markdown/bao_markdown.dart';
import 'package:baocode/chat/chat_models.dart';
import 'package:baocode/chat/chat_screen.dart';
import 'package:baocode/chat/chat_session.dart';
import 'package:baocode/chat/composer/composer.dart';
import 'package:baocode/kernel/agent_kernel.dart';
import 'package:baocode/kernel/claude_code/claude_code_kernel.dart';
import 'package:baocode/kernel/kernel_event.dart';
import 'package:baocode/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../composer_test.dart' show typeText, pressKey, composerController;
import '../kernel_test.dart' show FakeCli;

void main() {
  Future<({ChatSession session, ClaudeCodeKernel kernel, FakeCli cli})> pump(
    WidgetTester tester, {
    bool refusesRewind = false,
  }) async {
    final cli = FakeCli(
      answers: {
        'rewind_conversation': {'rewound': !refusesRewind},
      },
    );
    late ClaudeCodeKernel kernel;
    late final KernelDescriptor descriptor;
    descriptor = KernelDescriptor(
      id: 'claude-code',
      label: 'Claude Code',
      icon: Icons.auto_awesome_rounded,
      description: '',
      create: (context) => kernel = ClaudeCodeKernel(
        descriptor,
        context,
        start: (_) async => cli,
      ),
    );
    final session = ChatSession(
      kernel: descriptor,
      kernels: [descriptor],
      historyCount: 0,
      kernelContext: const KernelContext(cwd: '/tmp/project'),
    );
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: ChatScreen(session: session),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    return (session: session, kernel: kernel, cli: cli);
  }

  for (final escape in [true, false]) {
    testWidgets(
      'immediate ${escape ? 'Escape' : 'Stop click'} lets Up take the message back',
      (tester) async {
        final (:session, kernel: _, :cli) = await pump(tester);
        await typeText(tester, 'please fix this');
        await pressKey(tester, LogicalKeyboardKey.enter);
        expect(session.isStreaming, isTrue);
        if (escape) {
          await pressKey(tester, LogicalKeyboardKey.escape);
        } else {
          await tester.tap(find.byTooltip(RegExp(r'^Stop')));
          await tester.pump();
        }
        expect(session.canTakeBackStoppedPrompt, isTrue);
        await pressKey(tester, LogicalKeyboardKey.arrowUp);
        await tester.pump(const Duration(milliseconds: 100));
        expect(cli.requests('rewind_conversation'), hasLength(1));
        expect(session.itemCount, 0);
        expect(composerController(tester).text, 'please fix this');
        expect(session.draft.content, 'please fix this');
        // It is editable and sends as one new message, not a duplicate.
        await typeText(tester, ' instead');
        await pressKey(tester, LogicalKeyboardKey.enter);
        final users = [
          for (var i = 0; i < session.itemCount; i++)
            if (session.itemAt(i) case final UserMessageItem user) user,
        ];
        expect(users.single.text, 'please fix this instead');
      },
    );
  }

  testWidgets(
    'once a reply appears Up only recalls, without removing the turn',
    (tester) async {
      final (:session, :kernel, :cli) = await pump(tester);
      await typeText(tester, 'keep the reply');
      await pressKey(tester, LogicalKeyboardKey.enter);
      kernel.emit(
        ItemUpserted(
          kernel.nextSeq,
          'reply',
          const AssistantTextItem('working'),
        ),
      );
      await tester.pump();
      session.stop();
      await tester.pump();
      expect(session.canTakeBackStoppedPrompt, isFalse);
      final before = session.itemCount;
      await pressKey(tester, LogicalKeyboardKey.arrowUp);
      expect(session.itemCount, before);
      expect(cli.requests('rewind_conversation'), isEmpty);
      expect(composerController(tester).text, 'keep the reply');
    },
  );

  testWidgets('a declined rewind leaves the message and draft untouched', (
    tester,
  ) async {
    final (:session, kernel: _, :cli) = await pump(tester, refusesRewind: true);
    await typeText(tester, 'do not lose me');
    await pressKey(tester, LogicalKeyboardKey.enter);
    session.stop();
    await tester.pump();
    await pressKey(tester, LogicalKeyboardKey.arrowUp);
    await tester.pump(const Duration(milliseconds: 100));
    expect(cli.requests('rewind_conversation'), hasLength(1));
    expect(session.itemAt(0), isA<UserMessageItem>());
    expect(composerController(tester).text, isEmpty);
  });

  testWidgets(
    'taking back preserves attachments and does not overwrite a new draft',
    (tester) async {
      final (:session, kernel: _, :cli) = await pump(tester);
      final image = ImageAttachment(
        bytes: base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
        ),
        mediaType: 'image/png',
      );
      session.send(ComposerMessage(text: 'check this', images: [image]));
      await tester.pump();
      session.stop();
      await tester.pump();
      // A new draft uses ordinary history navigation, never a destructive rewind.
      await typeText(tester, 'new draft');
      composerController(tester).selection = const TextSelection.collapsed(
        offset: 0,
      );
      await pressKey(tester, LogicalKeyboardKey.arrowUp);
      expect(cli.requests('rewind_conversation'), isEmpty);
      composerController(tester).clear();
      await tester.pump();
      await session.takeBackStoppedPrompt();
      await tester.pump();
      expect(session.itemCount, 0);
      final composer = tester.widget<MarkdownEditor>(
        find.descendant(
          of: find.byType(ChatComposer),
          matching: find.byType(MarkdownEditor),
        ),
      );
      expect(composer.controller.text, contains('check this'));
      expect(session.draft.images.single.bytes, image.bytes);
    },
  );
}
