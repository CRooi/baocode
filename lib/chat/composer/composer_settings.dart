import 'package:flutter/foundation.dart';

/// Settings → General's switches for the composer, each as settings.json
/// has it; main() points [current] and [changes] at settings.json.

/// Agent always: the mode picker hidden, every message sent in Agent.
abstract final class AgentModeOnlySetting {
  static const settingKey = 'chat.composer.agentModeOnly';

  /// Written when on; off, the setting is left out.
  static const on = true;

  /// Off unless set to true.
  static bool enabled(Object? setting) => setting == true;

  static bool Function() current = () => false;
  static Listenable? changes;
}

/// A list item's prefix (`- `, `* `, `1. `) carried to the line Enter
/// makes, as editors do; Enter on an item left empty ends the list.
abstract final class ListContinuationSetting {
  static const settingKey = 'chat.composer.continueLists';

  /// Written when off; on, the setting is left out.
  static const off = false;

  /// On unless set to false.
  static bool enabled(Object? setting) => setting != false;

  static bool Function() current = () => true;
  static Listenable? changes;
}

/// The model picker cut to Claude's newest of each family (Opus, Sonnet,
/// Fable, Haiku), with effort and context choices beside them and the rest
/// under More models; on Claude Code's CLI only.
abstract final class SimpleModelPickerSetting {
  static const settingKey = 'chat.composer.simpleModelPicker';

  /// Written when on; off, the setting is left out.
  static const on = true;

  /// Off unless set to true.
  static bool enabled(Object? setting) => setting == true;

  static bool Function() current = () => false;
  static Listenable? changes;
}
