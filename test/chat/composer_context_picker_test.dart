import 'package:baocode/chat/chat_screen.dart';
import 'package:baocode/chat/chat_session.dart';
import 'package:baocode/chat/composer/composer_picker.dart';
import 'package:baocode/chat/composer/composer_settings.dart';
import 'package:baocode/chat/composer/session_model_picker.dart';
import 'package:baocode/chat/panels/context_usage_panel.dart';
import 'package:baocode/kernel/agent_kernel.dart';
import 'package:baocode/kernel/claude_code/claude_code_kernel.dart';
import 'package:baocode/kernel/claude_code/claude_core_setting.dart';
import 'package:baocode/kernel/kernel_event.dart';
import 'package:baocode/kernel/kernel_types.dart';
import 'package:baocode/models/model_provider.dart';
import 'package:baocode/models/model_providers.dart';
import 'package:baocode/theme/app_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../kernel_test.dart' show FakeCli;

const _gateway = ModelProvider(
  id: 'gw',
  name: 'Gateway',
  protocol: ProviderProtocol.openaiChat,
  baseUrl: 'https://gw.example.com/v1',
  models: [ProviderModel(id: 'custom', contextWindow: 400000)],
);

void main() {
  setUp(() {
    final simple = SimpleModelPickerSetting.current;
    final core = ClaudeCore.current;
    SimpleModelPickerSetting.current = () => true;
    ClaudeCore.current = () => ClaudeCore.cli;
    ClaudeCodeKernel.forgetAccount();
    addTearDown(() {
      SimpleModelPickerSetting.current = simple;
      ClaudeCore.current = core;
      ClaudeCodeKernel.forgetAccount();
    });
  });

  Future<({ChatSession session, ClaudeCodeKernel kernel, FakeCli cli})> pump(
    WidgetTester tester, {
    String model = 'opus',
    String contextSize = '400k',
    FakeCli? refreshCli,
  }) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cli = FakeCli(
      answers: {
        'get_context_usage': {
          'maxTokens': parseTokens(contextSize),
          'rawMaxTokens': 1000000,
          'totalTokens': 0,
          'model': 'claude-opus-5-5',
          'categories': <Object?>[],
        },
        'get_usage': {
          'rate_limits_available': true,
          'rate_limits': {
            'five_hour': {'utilization': 95},
            'seven_day': {'utilization': 80},
          },
        },
      },
    );
    final providers = ModelProviders.memory(providers: [_gateway]);
    addTearDown(providers.dispose);
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
        start: (launch) async =>
            !launch.persist && refreshCli != null ? refreshCli : cli,
        providers: providers,
        providerEnvironment: (_, _) async => {},
      ),
    );
    final session = ChatSession(
      kernel: descriptor,
      kernels: [descriptor],
      historyCount: 0,
      kernelContext: KernelContext(
        cwd: '/tmp/project',
        settings: {'model': model, 'context': contextSize},
      ),
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

  test('the simple picker shows the newest of each family, over an alias '
      'that names an older one', () {
    const group = KernelOptionGroup(builtinProviderId, 'Claude Code');
    KernelOption option(String id, String label) =>
        KernelOption(id, label, Icons.bolt_rounded, '', group: group);
    final newest = SessionModelPicker.newestOfFamilies([
      option('default', 'Default'),
      option('opus', 'Opus 5.5'),
      option('sonnet', 'Sonnet 5.5'),
      option('fable', 'Fable 5.1'),
      option('haiku', 'Haiku 5.5'),
      option('claude-fable-5-2', 'Fable 5.2'),
      option('claude-opus-5', 'Opus 5'),
      option('claude-opus-4-8', 'Opus 4.8'),
      option('claude-sonnet-4-6', 'Sonnet 4.6'),
    ]);
    expect(newest.map((o) => o.label), [
      'Opus 5.5',
      'Sonnet 5.5',
      'Fable 5.2',
      'Haiku 5.5',
    ]);
  });

  testWidgets(
    'model refresh updates the open picker without restarting its session',
    (tester) async {
      final fresh = FakeCli(
        answers: {
          'initialize': {
            'models': [
              {'value': 'opus', 'displayName': 'Opus Refreshed'},
              {'value': 'sonnet', 'displayName': 'Sonnet Refreshed'},
            ],
          },
        },
      );
      final (:session, :kernel, :cli) = await pump(tester, refreshCli: fresh);
      session.send(const ComposerMessage(text: 'keep working'));
      await tester.pump(const Duration(milliseconds: 100));
      final wasStreaming = session.isStreaming;
      await tester.tap(find.byType(SessionModelPicker));
      await tester.pump(const Duration(milliseconds: 300));
      // Shown beside the Claude Code heading only while it is pointed at.
      expect(find.byTooltip('Refresh Claude Code models'), findsNothing);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('Claude Code').last));
      await tester.pump();
      await tester.tap(find.byTooltip('Refresh Claude Code models'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(fresh.requests('initialize'), hasLength(1));
      expect(fresh.users, isEmpty);
      expect(fresh.closed, isTrue);
      expect(cli.closed, isFalse);
      expect(session.isStreaming, wasStreaming);
      expect(
        kernel.model.options.map((o) => o.label),
        contains('Opus Refreshed'),
      );
      expect(find.text('Opus Refreshed'), findsWidgets);
      await mouse.moveTo(tester.getCenter(find.text('Claude Code').last));
      await tester.pump();
      expect(find.byTooltip('Refresh Claude Code models'), findsOneWidget);
    },
  );

  testWidgets(
    'a failed model refresh keeps the existing catalog and closes its probe',
    (tester) async {
      final fresh = FakeCli(answers: {'initialize': {}});
      final (:session, :kernel, :cli) = await pump(tester, refreshCli: fresh);
      final before = kernel.model.options.map((o) => o.id).toList();
      await expectLater(session.refreshModels(), throwsStateError);
      expect(kernel.model.options.map((o) => o.id), before);
      expect(fresh.closed, isTrue);
      expect(cli.closed, isFalse);
    },
  );

  testWidgets('simple picker offers context below effort and preserves it '
      'when picking a model', (tester) async {
    final (:session, :kernel, cli: _) = await pump(tester);
    expect(session.selected(KernelChoiceKind.context), '400k');
    await tester.tap(find.byType(SessionModelPicker));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Context length'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Context length')).dy,
      greaterThan(tester.getTopLeft(find.text('Effort')).dy),
    );
    final picker = tester.widget<ComposerPicker>(
      find.descendant(
        of: find.byType(SessionModelPicker),
        matching: find.byType(ComposerPicker),
      ),
    );
    final contextRow = picker.options.singleWhere(
      (o) => o.label == 'Context length',
    );
    final contexts = picker.submenuOf!(contextRow);
    expect(contexts.map((o) => o.label), containsAll(['200K', '400K', '1M']));
    expect(
      picker.checks!(contexts.singleWhere((o) => o.label == '400K')),
      isTrue,
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('Context length')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('1M'), findsOneWidget);
    await tester.tap(find.text('1M'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(session.selected(KernelChoiceKind.context), '1m');
    picker.onSelected(picker.options.singleWhere((o) => o.id == 'opus'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(kernel.contextSize.selected, '1m');
  });

  testWidgets('third-party ring shows context despite cached Claude quota '
      'and never requests account usage', (tester) async {
    final (:session, :kernel, :cli) = await pump(tester);
    await kernel.refreshUsage();
    await tester.pump();
    expect(session.stats!.limits, isNotEmpty);
    kernel.model.select('@gw/custom');
    await tester.pump(const Duration(milliseconds: 100));
    kernel.emit(
      UsageReported(
        kernel.nextSeq,
        const ContextUsage(window: 400000, used: 100000),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    expect(session.reportsAccountUsage, isFalse);
    expect(session.stats!.limits, isEmpty);
    final before = cli.requests('get_usage').length;
    final ring = find.byTooltip(
      RegExp(r'Context usage[\s\S]*100K / 400K \(25%\)'),
    );
    expect(ring, findsOneWidget);
    expect(find.byTooltip('Loading…'), findsNothing);
    final paint = tester.widget<CustomPaint>(
      find.descendant(of: ring, matching: find.byType(CustomPaint)).last,
    );
    final dynamic painter = paint.painter;
    expect(painter.fraction, closeTo(.25, 1e-9));
    await tester.tap(ring);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ContextUsagePanel), findsOneWidget);
    expect(find.text('Plan usage'), findsNothing);
    session.refreshUsage();
    await kernel.refreshUsage();
    await tester.pump(const Duration(seconds: 1));
    expect(cli.requests('get_usage'), hasLength(before));
    expect(kernel.accountLimits, isEmpty);
  });

  testWidgets(
    'third-party simple picker uses the selected model context options',
    (tester) async {
      final (:session, kernel: _, cli: _) = await pump(
        tester,
        model: '@gw/custom',
        contextSize: '400000',
      );
      expect(session.reportsAccountUsage, isFalse);
      await tester.tap(find.byType(SessionModelPicker));
      await tester.pump(const Duration(milliseconds: 300));
      final picker = tester.widget<ComposerPicker>(
        find.descendant(
          of: find.byType(SessionModelPicker),
          matching: find.byType(ComposerPicker),
        ),
      );
      final row = picker.options.singleWhere(
        (o) => o.label == 'Context length',
      );
      final sizes = picker.submenuOf!(row);
      expect(sizes.map((o) => o.label), containsAll(['200K', '400K', '1M']));
      expect(
        picker.checks!(sizes.singleWhere((o) => o.label == '400K')),
        isTrue,
      );
      picker.onSelected(sizes.singleWhere((o) => o.label == '1M'));
      await tester.pump();
      expect(session.selected(KernelChoiceKind.context), '1000000');
      expect(session.models!.selected.id, '@gw/custom');
    },
  );
}
