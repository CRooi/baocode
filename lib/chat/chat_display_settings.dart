import 'package:flutter/widgets.dart';

import '../l10n/l10n.dart';

/// Settings → Appearance's choices of what a conversation shows, each as
/// settings.json has it; main() keeps each `current` to settings.json.

/// The language of the lines a status row muses while the agent thinks
/// ("Pondering", "冥思苦想"…): the app's, or one of its own.
/// settings.json's `chat.musingsLanguage`; unset, [app].
enum MusingsLanguage {
  app,
  zh,
  en;

  static const settingKey = 'chat.musingsLanguage';

  static MusingsLanguage parse(Object? value) => switch (value) {
    'zh' => zh,
    'en' => en,
    _ => app,
  };

  /// As settings.json keeps it; null (not written) for [app].
  Object? get setting => this == app ? null : name;

  /// The strings the musings are in, [l10n] being the app's.
  AppLocalizations of(AppLocalizations l10n) => switch (this) {
    app => l10n,
    zh => lookupAppLocalizations(const Locale('zh')),
    en => lookupAppLocalizations(const Locale('en')),
  };

  static final ValueNotifier<MusingsLanguage> current = ValueNotifier(app);

  /// Sets [current] from [read] now and whenever [changes] notifies.
  static void follow(Listenable changes, Object? Function() read) {
    void update() => current.value = parse(read());
    update();
    changes.addListener(update);
  }
}

/// Whether a long message the user sent shows its first lines only until
/// opened. settings.json's `chat.foldLongMessages`; unset, on.
abstract final class FoldLongMessages {
  static const settingKey = 'chat.foldLongMessages';

  static bool parse(Object? value) => value != false;

  /// As settings.json keeps it; null (not written) when on.
  static Object? setting(bool on) => on ? null : false;

  static final ValueNotifier<bool> current = ValueNotifier(true);

  static void follow(Listenable changes, Object? Function() read) {
    void update() => current.value = parse(read());
    update();
    changes.addListener(update);
  }
}

/// Whether the files the agent changed show above the composer, with
/// Undo all and Keep all. settings.json's `chat.showChangedFiles`; unset,
/// on.
abstract final class ShowChangedFiles {
  static const settingKey = 'chat.showChangedFiles';

  static bool parse(Object? value) => value != false;

  /// As settings.json keeps it; null (not written) when on.
  static Object? setting(bool on) => on ? null : false;

  static final ValueNotifier<bool> current = ValueNotifier(true);

  static void follow(Listenable changes, Object? Function() read) {
    void update() => current.value = parse(read());
    update();
    changes.addListener(update);
  }
}

/// Whether code the IDE's editor copied goes into the composer as a tag
/// of its lines; else as its text. settings.json's `chat.pasteCodeAsTag`;
/// unset, on.
abstract final class PasteCodeAsTag {
  static const settingKey = 'chat.pasteCodeAsTag';

  static bool parse(Object? value) => value != false;

  /// As settings.json keeps it; null (not written) when on.
  static Object? setting(bool on) => on ? null : false;

  static final ValueNotifier<bool> current = ValueNotifier(true);

  static void follow(Listenable changes, Object? Function() read) {
    void update() => current.value = parse(read());
    update();
    changes.addListener(update);
  }
}

/// The size of a conversation's text: the model's replies and the user's
/// messages. settings.json's `chat.fontSize`; unset, [defaultSize].
abstract final class ChatFontSize {
  static const settingKey = 'chat.fontSize';

  static const defaultSize = 13.5;

  static const steps = <double>[12, 12.5, 13, 13.5, 14, 14.5, 15, 16, 17, 18];

  static double parse(Object? value) => switch (value) {
    final num size when size >= steps.first && size <= steps.last =>
      size.toDouble(),
    _ => defaultSize,
  };

  /// As settings.json keeps it; null (not written) for [defaultSize].
  static Object? setting(double size) => size == defaultSize ? null : size;

  /// The step nearest [size].
  static int stepOf(double size) {
    var best = 0;
    for (var i = 1; i < steps.length; i++) {
      if ((steps[i] - size).abs() < (steps[best] - size).abs()) best = i;
    }
    return best;
  }

  static final ValueNotifier<double> current = ValueNotifier(defaultSize);

  /// [current] over [defaultSize]: what the sizes made for the default
  /// (headings, inline code) are scaled by.
  static double get scale => current.value / defaultSize;

  static void follow(Listenable changes, Object? Function() read) {
    void update() => current.value = parse(read());
    update();
    changes.addListener(update);
  }
}

/// Whether the model's thoughts show open, as they stream and once done,
/// until closed by hand; else closed, while they stream too, until opened.
/// settings.json's `chat.expandThinking`; unset, off.
abstract final class ExpandThinking {
  static const settingKey = 'chat.expandThinking';

  static bool parse(Object? value) => value == true;

  /// As settings.json keeps it; null (not written) when off.
  static Object? setting(bool on) => on ? true : null;

  static final ValueNotifier<bool> current = ValueNotifier(false);

  static void follow(Listenable changes, Object? Function() read) {
    void update() => current.value = parse(read());
    update();
    changes.addListener(update);
  }
}
