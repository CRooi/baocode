import 'package:flutter/material.dart';

import '../chat/chat_session.dart' show ModelSettingChoice;
import '../chat/composer/composer_picker.dart';
import '../kernel/agent_kernel.dart' show KernelChoiceKind;
import '../kernel/kernel_types.dart';
import '../l10n/l10n.dart';
import 'model_icons.dart';
import 'model_provider.dart';
import 'model_providers.dart';

/// The composer's model picker over the upstreams' models, for a setting:
/// [noneLabel] first (null, none picked), then each upstream's models, the
/// effort of each beside it. [model] is a [modelRef], picked at [effort].
class ProviderModelPicker extends StatelessWidget {
  const ProviderModelPicker({
    super.key,
    required this.providers,
    required this.model,
    required this.effort,
    required this.noneLabel,
    required this.onPicked,
  });

  final ModelProviders providers;
  final String? model;
  final String? effort;
  final String noneLabel;
  final void Function(String? model, String? effort) onPicked;

  static const _none = '';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: providers,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final none = KernelOption(_none, noneLabel, Icons.sync_alt_rounded, '');
    final infos = <String, ProviderModel>{};
    final options = [none];
    for (final provider in providers.enabled) {
      final group = KernelOptionGroup(
        provider.id,
        provider.name,
        iconBuilder: (size, color) =>
            ProviderIcon(provider.id, size: size, color: color),
      );
      for (final info in provider.enabledModels) {
        if (info.kind.generatesImages) continue;
        final id = modelRef(provider.id, info.id);
        infos[id] = info;
        options.add(
          KernelOption(
            id,
            info.displayName,
            Icons.hub_outlined,
            '',
            group: group,
            iconBuilder: (size, color) => ModelIcon(
              provider: provider.id,
              model: info.id,
              size: size,
              color: color,
            ),
          ),
        );
      }
    }
    final current = switch (providers.resolve(model)) {
      (final provider, final info) => modelRef(provider.id, info.id),
      null => _none,
    };
    final selected =
        options.where((option) => option.id == current).firstOrNull ?? none;

    /// [option]'s effort: as picked while it is the one picked, else its own.
    String? effortOf(String option) {
      final levels = infos[option]?.effortLevels ?? const <String>[];
      if (option == selected.id && levels.contains(effort)) return effort;
      return infos[option]?.initialEffort;
    }

    final shownEffort = selected.id == _none ? null : effortOf(selected.id);
    return ComposerPicker(
      options: options,
      selected: selected,
      label: selected.label,
      labelAside: shownEffort == null ? null : effortLabel(shownEffort),
      describes: false,
      menuWidth: 260,
      searchPlaceholder: context.l10n.modelsSearch,
      settingsOf: (option) {
        final levels = infos[option.id]?.effortLevels ?? const <String>[];
        if (levels.isEmpty) return const [];
        final choices = [
          for (final level in levels)
            KernelOption(level, effortLabel(level), Icons.speed_rounded, ''),
        ];
        final picked = effortOf(option.id);
        return [
          ModelSettingChoice(
            kind: KernelChoiceKind.effort,
            options: choices,
            selected: choices.where((c) => c.id == picked).firstOrNull,
            onSelected: (choice) => onPicked(option.id, choice.id),
          ),
        ];
      },
      onSelected: (option) => option.id == _none
          ? onPicked(null, null)
          : onPicked(option.id, effortOf(option.id)),
    );
  }
}
