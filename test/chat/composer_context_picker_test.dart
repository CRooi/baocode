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
        start: (_) async => cli,
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
