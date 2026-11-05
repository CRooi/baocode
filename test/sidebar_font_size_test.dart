import 'package:baocode/sidebar/sidebar_font_size.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(
    () => SidebarFontSize.current.value = SidebarFontSize.defaultSize,
  );

  test('settings.json keeps a size in range, nothing for the default', () {
    expect(SidebarFontSize.parse(null), SidebarFontSize.defaultSize);
    expect(SidebarFontSize.parse(40), SidebarFontSize.defaultSize);
    expect(SidebarFontSize.parse('14'), SidebarFontSize.defaultSize);
    expect(SidebarFontSize.parse(14), 14);
    expect(SidebarFontSize.setting(SidebarFontSize.defaultSize), isNull);
    expect(SidebarFontSize.setting(14), 14);
  });

  test('rows and text grow with the size', () {
    expect(SidebarFontSize.scaled(22), 22);
    expect(
      SidebarFontSize.textScaler(TextScaler.noScaling),
      TextScaler.noScaling,
    );
    SidebarFontSize.current.value = 15;
    expect(SidebarFontSize.scaled(22), 26);
    expect(
      SidebarFontSize.textScaler(const TextScaler.linear(2)).scale(12.5),
      closeTo(30, 1e-9),
    );
  });
}
