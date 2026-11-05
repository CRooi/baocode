import 'package:flutter/widgets.dart';

/// settings.json's `sidebar.fontSize`: the size of the sidebar's list, its
/// projects' and agents' rows growing with their text. Unset, [defaultSize].
abstract final class SidebarFontSize {
  static const settingKey = 'sidebar.fontSize';

  /// An agent's row's text as the sidebar was made for.
  static const defaultSize = 12.5;

  static const steps = <double>[11.5, 12, 12.5, 13, 13.5, 14, 15, 16];

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

  /// The size now; main() keeps it to settings.json ([follow]).
  static final ValueNotifier<double> current = ValueNotifier(defaultSize);

  /// [current] over [defaultSize].
  static double get scale => current.value / defaultSize;

  /// [extent], made for [defaultSize], at [current], in whole pixels.
  static double scaled(double extent) => (extent * scale).roundToDouble();

  /// The text scaler under [outer] that sizes the list's text at [current].
  static TextScaler textScaler(TextScaler outer) =>
      scale == 1 ? outer : _Times(outer, scale);

  static void follow(Listenable changes, Object? Function() read) {
    void update() => current.value = parse(read());
    update();
    changes.addListener(update);
  }
}

/// [outer], then times [factor].
class _Times extends TextScaler {
  const _Times(this.outer, this.factor);

  final TextScaler outer;
  final double factor;

  @override
  double scale(double fontSize) => outer.scale(fontSize) * factor;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => outer.textScaleFactor * factor;

  @override
  bool operator ==(Object other) =>
      other is _Times && other.outer == outer && other.factor == factor;

  @override
  int get hashCode => Object.hash(outer, factor);
}
