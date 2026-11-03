import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baocode/l10n/l10n.dart';
import 'package:baocode/settings/settings_dialog.dart' show SettingsSection;
import 'package:baocode/settings/settings_index.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final zh = lookupAppLocalizations(const Locale('zh'));

  test('a search finds the settings themselves, with their page', () {
    final found = searchSettings(en, en.appearanceSettingsCodeFont);
    expect(found, isNotEmpty);
    expect(found.first.section, SettingsSection.appearance);
    expect(found.first.label, en.appearanceSettingsCodeFont);
  });

  test('any case, in either language, by description too', () {
    expect(
      searchSettings(en, en.networkProxy.toUpperCase()).map((e) => e.label),
      contains(en.networkProxy),
    );
    expect(
      searchSettings(zh, zh.generalSettingsContinueLists).map((e) => e.label),
      contains(zh.generalSettingsContinueLists),
    );
    final description = en.generalSettingsAgentModeOnlyDescription;
    expect(
      searchSettings(en, description).map((e) => e.label),
      contains(en.generalSettingsAgentModeOnly),
    );
  });

  test('an empty search, or one nothing matches, finds nothing', () {
    expect(searchSettings(en, '  '), isEmpty);
    expect(searchSettings(en, 'zzqqxx-no-such-setting'), isEmpty);
  });

  test('no label is listed twice on one page', () {
    for (final l10n in [en, zh]) {
      final seen = <(SettingsSection, String)>{};
      for (final entry in settingsEntries(l10n)) {
        expect(seen.add((entry.section, entry.label)), isTrue,
            reason: '${entry.section} ${entry.label}');
      }
    }
  });
}
