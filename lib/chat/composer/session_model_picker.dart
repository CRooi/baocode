import 'dart:async';

import 'package:flutter/material.dart';

import '../../channel/channel_setup.dart' show ChannelSetup;
import '../../ide/ide_dialog.dart';
import '../../kernel/agent_kernel.dart';
import '../../kernel/claude_code/claude_core_setting.dart';
import '../../kernel/kernel_types.dart';
import '../../l10n/l10n.dart';
import '../../models/model_provider.dart' show builtinProviderId, parseModelRef;
import '../../models/model_providers.dart';
import '../../models/model_runtime.dart' show codexService;
import '../../models/model_welcome.dart';
import '../../settings/settings_dialog.dart'
    show SettingsOpener, SettingsSection;
import '../../theme/app_theme.dart';
import '../../theme/codicons.dart';
import '../chat_session.dart';
import '../resume_after_reset.dart';
import '../widgets/hover_builder.dart';
import 'composer_picker.dart';
import 'composer_settings.dart';

/// The pill that picks [session]'s model, each model's settings (its
/// effort, its context) beside it: the composer's, and the one a plan is
/// started with. With no model to run on, one that sets a model up
/// ([showModelWelcome]); nothing where the kernel picks no model.
class SessionModelPicker extends StatelessWidget {
  const SessionModelPicker({
    super.key,
    required this.session,
    this.pickerKey,
    this.tooltip,
    this.tapRegionGroupId,
    this.focusNode,
  });

  final ChatSession session;

  /// The picker's own, to open it from a keybinding.
  final GlobalKey<ComposerPickerState>? pickerKey;

  /// See [ComposerPicker.tooltip], [ComposerPicker.tapRegionGroupId] and
  /// [ComposerPicker.focusNode].
  final String? tooltip;
  final Object? tapRegionGroupId;
  final FocusNode? focusNode;

  /// The model, e.g. "Opus 5.5": its upstream before it only when another
  /// upstream has a model of its name.
  String _label(KernelOption model, List<KernelOption> options) => [
    if (model.group case final group?
        when options.any(
          (other) => other.label == model.label && other.group?.id != group.id,
        ))
      group.label,
    model.label,
  ].join(' ');

  /// Its settings after it, fainter, e.g. "1M High": the context only when
  /// it is not the standard one; null with none.
  String? _settingsLabel(KernelOption model) {
    final labels = [
      for (final setting in session.modelSettings(model.id))
        if (setting.selected case final selected?
            when setting.kind != KernelChoiceKind.context ||
                selected != setting.options.first)
          selected.label,
    ];
    return labels.isEmpty ? null : labels.join(' ');
  }

  /// Runs [pick], which switches to [option]: once confirmed, if that
  /// restarts the agent on another upstream mid-conversation.
  Future<void> _switch(
    BuildContext context,
    KernelOption option,
    VoidCallback pick,
  ) async {
    if (!session.switchRestarts(option.id)) return pick();
    final l10n = context.l10n;
    final choice = await showIdeDialog(
      context,
      message: l10n.modelsSwitchTitle(option.group?.label ?? option.label),
      detail: l10n.modelsSwitchDetail,
      buttons: [l10n.modelsSwitchConfirm],
      type: IdeDialogType.question,
    );
    if (choice == 0 && context.mounted) pick();
  }

  /// Beside a model of the account's plan, last: whether an agent stopped
  /// at its usage limit goes on by itself once it resets. Not where it
  /// cannot be set.
  ModelSettingChoice? _resumeAfterLimit(BuildContext context, String model) {
    final write = ResumeAfterResetSetting.write;
    if (write == null || !session.continuesAfterLimit(model)) return null;
    final on = KernelOption(
      'on',
      context.l10n.resumeAfterLimitToggle,
      Icons.schedule_send_rounded,
      '',
    );
    final enabled = ResumeAfterResetSetting.current();
    return ModelSettingChoice(
      kind: null,
      options: [on],
      selected: enabled ? on : null,
      toggle: true,
      onSelected: (_) => write(!enabled),
    );
  }

  /// Beside a model of ChatGPT accounts, last: whether an account out of
  /// quota uses up a reset credit of its own by itself.
  ModelSettingChoice? _autoResetCredits(BuildContext context, String model) {
    final providers = ModelProviders.current;
    final provider = providers.provider(parseModelRef(model)?.provider);
    if (provider == null || !provider.protocol.usesAccounts) return null;
    final on = KernelOption(
      'on',
      context.l10n.autoResetCreditsToggle,
      Icons.restart_alt_rounded,
      '',
    );
    final enabled = provider.autoResetCredits;
    return ModelSettingChoice(
      kind: null,
      options: [on],
      selected: enabled ? on : null,
      toggle: true,
      onSelected: (_) => unawaited(() async {
        final now = providers.provider(provider.id) ?? provider;
        await providers.save(now.copyWith(autoResetCredits: !enabled));
        // Turned on: one out of quota already uses its credit now.
        if (!enabled) {
          await codexService.refreshUsage(
            providers.provider(provider.id) ?? now,
          );
        }
      }()),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    // Its switches turned, as settings.json says.
    listenable: Listenable.merge([
      ?ResumeAfterResetSetting.changes,
      ?SimpleModelPickerSetting.changes,
      ModelProviders.current,
    ]),
    builder: (context, _) => _build(context),
  );

  /// The families the simple picker lists, in its order.
  static const _families = ['opus', 'sonnet', 'fable', 'haiku'];

  /// Ids of the simple picker's own rows, apart from the models'.
  static const _effortRow = '\u0000effort';
  static const _contextRow = '\u0000context';
  static const _moreRow = '\u0000more';
  static const _effortPrefix = '\u0000effort:';
  static const _contextPrefix = '\u0000context:';

  /// Of Claude Code's own models (the CLI's), the newest of each of
  /// [_families], in that order: the family's alias (`opus`) first, else
  /// the one named for it with the highest version. None where the CLI's
  /// models are not known yet.
  @visibleForTesting
  static List<KernelOption> newestOfFamilies(List<KernelOption> options) {
    final builtin = [
      for (final option in options)
        if (option.group?.id == builtinProviderId && option.id != 'default')
          option,
    ];
    int version(KernelOption option) {
      final digits = RegExp(r'\d+').allMatches(option.id);
      var value = 0;
      for (final match in digits.take(3)) {
        value = value * 1000 + int.parse(match[0]!);
      }
      return value;
    }

    KernelOption? newest(String family) =>
        builtin.where((o) => o.id == family).firstOrNull ??
        (builtin
                .where(
                  (o) =>
                      o.id.toLowerCase().contains(family) ||
                      o.label.toLowerCase().contains(family),
                )
                .toList()
              ..sort((a, b) => version(b) - version(a)))
            .firstOrNull;

    return [for (final family in _families) ?newest(family)];
  }

  /// The simple picker (Settings → General), on Claude Code's CLI: the
  /// newest of each family, effort and context, and the rest under More models.
  /// Null where it does not apply, for the full one.
  Widget? _buildSimple(BuildContext context, KernelChoice model) {
    if (!SimpleModelPickerSetting.current() ||
        session.kernel.id != 'claude-code' ||
        ClaudeCore.current() != ClaudeCore.cli) {
      return null;
    }
    final newest = newestOfFamilies(model.options);
    if (newest.isEmpty) return null;
    final l10n = context.l10n;
    final rest = [
      for (final option in model.options)
        if (!newest.contains(option)) option,
    ];
    final settings = session.modelSettings(model.selected.id);
    final effort = settings
        .where((setting) => setting.kind == KernelChoiceKind.effort)
        .firstOrNull;
    final contextSize = settings
        .where((setting) => setting.kind == KernelChoiceKind.context)
        .firstOrNull;
    final contexts = [
      for (final option in contextSize?.options ?? const <KernelOption>[])
        KernelOption(
          '$_contextPrefix${option.id}',
          option.label,
          option.icon,
          '',
        ),
    ];
    final contextRow = KernelOption(
      _contextRow,
      l10n.composerSettingContextLength,
      Icons.notes_rounded,
      '',
    );
    final efforts = [
      for (final option in effort?.options ?? const <KernelOption>[])
        KernelOption(
          '$_effortPrefix${option.id}',
          option.label,
          option.icon,
          '',
        ),
    ];
    final effortRow = KernelOption(
      _effortRow,
      l10n.composerSettingEffort,
      Icons.speed_rounded,
      '',
    );
    final moreRow = KernelOption(
      _moreRow,
      l10n.composerMoreModels,
      Icons.more_horiz_rounded,
      '',
    );

    void pickModel(KernelOption option) =>
        unawaited(_switch(context, option, () => model.onSelected(option)));

    return ComposerPicker(
      key: pickerKey,
      options: [
        ...newest,
        if (efforts.isNotEmpty) effortRow,
        if (contexts.isNotEmpty) contextRow,
        if (rest.isNotEmpty) moreRow,
      ],
      selected: model.selected,
      label: _label(model.selected, model.options),
      labelAside: _settingsLabel(model.selected),
      describes: false,
      submenuOf: (option) => switch (option.id) {
        _effortRow => efforts,
        _contextRow => contexts,
        _moreRow => rest,
        _ => const [],
      },
      checks: (option) => option.id.startsWith(_effortPrefix)
          ? option.id == '$_effortPrefix${effort?.selected?.id}'
          : option.id.startsWith(_contextPrefix)
          ? option.id == '$_contextPrefix${contextSize?.selected?.id}'
          : option == model.selected,
      tooltip: tooltip,
      menuWidth: 260,
      footers: [
        if (SettingsOpener.maybeOf(context) case final open?)
          (
            label: ChannelSetup.channelBuild
                ? l10n.channelAccountTitle
                : l10n.modelsManage,
            icon: Icons.tune_rounded,
            onTap: () => open(SettingsSection.models),
          ),
      ],
      tapRegionGroupId: tapRegionGroupId,
      focusNode: focusNode,
      onSelected: (option) {
        if (option.id.startsWith(_effortPrefix)) {
          final id = option.id.substring(_effortPrefix.length);
          final level = effort?.options.where((o) => o.id == id).firstOrNull;
          if (effort != null && level != null) effort.onSelected(level);
          return;
        }
        if (option.id.startsWith(_contextPrefix)) {
          final id = option.id.substring(_contextPrefix.length);
          final size = contextSize?.options
              .where((o) => o.id == id)
              .firstOrNull;
          if (contextSize != null && size != null) contextSize.onSelected(size);
          return;
        }
        pickModel(option);
      },
    );
  }

  Widget _build(BuildContext context) {
    final model = session.models;
    final l10n = context.l10n;
    if (model == null) {
      if (!session.health.noModel) return const SizedBox.shrink();
      return _SetUpPill(
        label: l10n.modelSetUp,
        onTap: () => unawaited(showModelWelcome(context)),
      );
    }
    if (_buildSimple(context, model) case final simple?) return simple;
    return ComposerPicker(
      key: pickerKey,
      options: model.options,
      selected: model.selected,
      label: _label(model.selected, model.options),
      labelAside: _settingsLabel(model.selected),
      // Each its name alone, one line; its maker's logo and its upstream's
      // heading tell the rest.
      describes: false,
      settingsOf: (option) => [
        for (final setting in session.modelSettings(option.id))
          ModelSettingChoice(
            kind: setting.kind,
            options: setting.options,
            selected: setting.selected,
            toggle: setting.toggle,
            onSelected: (choice) => unawaited(
              _switch(context, option, () => setting.onSelected(choice)),
            ),
          ),
        ?_resumeAfterLimit(context, option.id),
        ?_autoResetCredits(context, option.id),
      ],
      tooltip: tooltip,
      menuWidth: 260,
      searchPlaceholder: l10n.modelsSearch,
      footers: [
        if (SettingsOpener.maybeOf(context) case final open?)
          (
            label: ChannelSetup.channelBuild
                ? l10n.channelAccountTitle
                : l10n.modelsManage,
            icon: Icons.tune_rounded,
            onTap: () => open(SettingsSection.models),
          ),
      ],
      tapRegionGroupId: tapRegionGroupId,
      focusNode: focusNode,
      onSelected: (option) =>
          unawaited(_switch(context, option, () => model.onSelected(option))),
    );
  }
}

/// In the model's place while there is none: as its pill, in the accent,
/// a click away from setting one up.
class _SetUpPill extends StatelessWidget {
  const _SetUpPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent;
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: hovered ? .2 : .12),
            border: Border.all(color: accent.withValues(alpha: .4)),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Codicons.sparkle, size: 13, color: accent),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: accent, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
