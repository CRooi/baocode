import 'package:baocode/chat/chat_display_settings.dart';
import 'package:baocode/chat/widgets/markdown_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => ChatFontSize.current.value = ChatFontSize.defaultSize);

  test('unset or out of range, the default size', () {
    expect(ChatFontSize.parse(null), ChatFontSize.defaultSize);
    expect(ChatFontSize.parse(40), ChatFontSize.defaultSize);
    expect(ChatFontSize.parse('15'), ChatFontSize.defaultSize);
    expect(ChatFontSize.parse(15), 15);
    // The default not written to settings.json.
    expect(ChatFontSize.setting(ChatFontSize.defaultSize), isNull);
    expect(ChatFontSize.setting(16), 16);
  });

  test('the replies, their headings and code follow the size', () {
    final headings = const MarkdownOptions().headingSizes;
    expect(MarkdownView.baseStyle.fontSize, 13.5);
    final code = MarkdownView.codeStyle.fontSize!;
    ChatFontSize.current.value = 16.2;
    expect(MarkdownView.baseStyle.fontSize, 16.2);
    expect(MarkdownView.codeStyle.fontSize, closeTo(code * 1.2, 1e-9));
    expect(headings.first * ChatFontSize.scale, closeTo(19 * 1.2, 1e-9));
  });
}
