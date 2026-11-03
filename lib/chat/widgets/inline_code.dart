import 'dart:ui' show BoxHeightStyle;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import '../chat_find.dart' show ChatFindMarks;

/// Inline code: its text, on `textPreformat.background` painted by the
/// [InlineCodeText] it is in.
class InlineCodeSpan extends TextSpan {
  const InlineCodeSpan({
    super.text,
    super.style,
    super.children,
    super.recognizer,
    super.mouseCursor,
  });
}

/// [span] as [Text.rich] does, its [InlineCodeSpan]s on their background.
///
/// Not the text's own `backgroundColor`: a paragraph paints the selection
/// under its text, and that background with the text, over the selection:
/// opaque (Dark Modern's), it hid a selected code's highlight. Painted here
/// before the paragraph, the background is under the selection instead, in
/// every theme.
class InlineCodeText extends StatelessWidget {
  const InlineCodeText(this.span, {super.key, this.maxLines});

  final InlineSpan span;

  /// Cut to as many lines, an ellipsis at the end; all of it when null.
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final selectionStyle = DefaultSelectionStyle.of(context);
    return _InlineCodeBackdrop(
      color: AppColors.inlineCodeBackground,
      selectionColor: selectionStyle.selectionColor,
      // The paragraph's own highlight is as tall as each run's font
      // (code's, a fallback's for CJK), uneven along a line: the backdrop
      // paints it instead, a line high.
      child: DefaultSelectionStyle(
        cursorColor: selectionStyle.cursorColor,
        selectionColor: const Color(0x00000000),
        mouseCursor: selectionStyle.mouseCursor,
        child: ChatFindMarks(
          child: Text.rich(
            span,
            maxLines: maxLines,
            overflow: maxLines == null ? null : TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _InlineCodeBackdrop extends SingleChildRenderObjectWidget {
  const _InlineCodeBackdrop({
    required this.color,
    required this.selectionColor,
    required super.child,
  });

  final Color color;
  final Color? selectionColor;

  @override
  RenderInlineCodeBackdrop createRenderObject(BuildContext context) =>
      RenderInlineCodeBackdrop(color, selectionColor);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderInlineCodeBackdrop renderObject,
  ) => renderObject
    ..color = color
    ..selectionColor = selectionColor;
}

/// Paints, under its child, the background of each [InlineCodeSpan] of
/// the paragraph in it, and over those its selection, each line's as high
/// as the line.
class RenderInlineCodeBackdrop extends RenderProxyBox {
  RenderInlineCodeBackdrop(this._color, [this._selectionColor]);

  static const radius = Radius.circular(3);

  Color get color => _color;
  Color _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    markNeedsPaint();
  }

  /// The selection's highlight; none when null.
  Color? get selectionColor => _selectionColor;
  Color? _selectionColor;
  set selectionColor(Color? value) {
    if (value == _selectionColor) return;
    _selectionColor = value;
    markNeedsPaint();
  }

  /// [paragraph]'s selection, a box a line, each as high as its line.
  void _paintSelection(
    RenderParagraph paragraph,
    PaintingContext context,
    Offset offset,
  ) {
    final color = _selectionColor;
    if (color == null || color.a == 0) return;
    // ignore: invalid_use_of_visible_for_testing_member
    final selections = paragraph.selections;
    if (selections.isEmpty) return;
    final transform = paragraph.getTransformTo(this);
    final paint = Paint()..color = color;
    for (final selection in selections) {
      if (selection.isCollapsed) continue;
      for (final box in paragraph.getBoxesForSelection(
        selection,
        boxHeightStyle: BoxHeightStyle.max,
      )) {
        final rect = MatrixUtils.transformRect(transform, box.toRect());
        context.canvas.drawRect(rect.shift(offset), paint);
      }
    }
  }

  /// The paragraph within: [Text] may put a mouse region around it.
  RenderParagraph? get _paragraph {
    RenderObject? node = child;
    while (node != null && node is! RenderParagraph) {
      RenderObject? only;
      node.visitChildren((c) => only ??= c);
      node = only;
    }
    return node as RenderParagraph?;
  }

  /// Where in [span]'s text each [InlineCodeSpan] is.
  static List<TextSelection> codeRanges(InlineSpan span) {
    final ranges = <TextSelection>[];
    var at = 0;
    void walk(InlineSpan span) {
      switch (span) {
        case TextSpan(:final text, :final children):
          final start = at;
          at += text?.length ?? 0;
          children?.forEach(walk);
          if (span is InlineCodeSpan && at > start) {
            ranges.add(TextSelection(baseOffset: start, extentOffset: at));
          }
        case PlaceholderSpan():
          // Its object replacement character.
          at += 1;
      }
    }

    walk(span);
    return ranges;
  }

  /// [range] without the spaces that pad it at either end.
  static TextSelection _trimmed(String text, TextSelection range) {
    var start = range.start;
    var end = range.end;
    while (start < end && text[start] == ' ') {
      start++;
    }
    while (end > start && text[end - 1] == ' ') {
      end--;
    }
    return TextSelection(baseOffset: start, extentOffset: end);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final paragraph = _paragraph;
    _paintCode(paragraph, context, offset);
    if (paragraph != null) _paintSelection(paragraph, context, offset);
    super.paint(context, offset);
  }

  void _paintCode(
    RenderParagraph? paragraph,
    PaintingContext context,
    Offset offset,
  ) {
    if (paragraph != null && _color.a > 0) {
      final ranges = codeRanges(paragraph.text);
      if (ranges.isNotEmpty) {
        final transform = paragraph.getTransformTo(this);
        final paint = Paint()..color = _color;
        final text = paragraph.text.toPlainText(includeSemanticsLabels: false);
        for (final range in ranges) {
          // A line may break after the code's leading space: that space alone
          // at the end of the line above is no code, so it gets no background.
          final lines = [
            for (final box in paragraph.getBoxesForSelection(
              _trimmed(text, range),
            ))
              box.toRect(),
          ];
          bool onCodeLine(Rect rect) => lines.any(
            (line) => line.top < rect.bottom && rect.top < line.bottom,
          );
          for (final box in paragraph.getBoxesForSelection(range)) {
            if (!onCodeLine(box.toRect())) continue;
            final rect = MatrixUtils.transformRect(transform, box.toRect());
            context.canvas.drawRRect(
              RRect.fromRectAndRadius(rect.shift(offset), radius),
              paint,
            );
          }
        }
      }
    }
  }
}
