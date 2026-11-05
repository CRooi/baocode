import '../l10n/l10n.dart';
import 'settings_dialog.dart' show SettingsSection;

/// One setting the dialog's search finds: the page it is on, its label as
/// the page shows it (which finds its row there, see SettingsTarget), and
/// its description, searched too.
typedef SettingsEntry = ({
  SettingsSection section,
  String label,
  String? description,
});

/// The settings the pages show, by page, in [l10n]'s words. A row added to
/// a page is added here too, to be found.
List<SettingsEntry> settingsEntries(AppLocalizations l10n) {
  SettingsEntry entry(
    SettingsSection section,
    String label, [
    String? description,
  ]) => (section: section, label: label, description: description);
  const general = SettingsSection.general;
  const appearance = SettingsSection.appearance;
  const notifications = SettingsSection.notifications;
  const network = SettingsSection.network;
  const browser = SettingsSection.browser;
  const mobile = SettingsSection.mobile;
  const ssh = SettingsSection.ssh;
  return [
    entry(
      general,
      l10n.generalSettingsMainWindow,
      l10n.generalSettingsMainWindowDescription,
    ),
    entry(general, l10n.generalSettingsWindows),
    entry(general, l10n.generalSettingsIde),
    entry(general, l10n.generalSettingsShellCommand),
    entry(general, l10n.claudePathSetting, l10n.claudePathSettingDescription),
    entry(
      general,
      l10n.explorerExcludeSetting,
      l10n.explorerExcludeSettingDescription,
    ),
    entry(
      general,
      l10n.generalSettingsCommitAttribution,
      l10n.generalSettingsCommitAttributionDescription,
    ),
    entry(
      general,
      l10n.generalSettingsComposerPolish,
      l10n.generalSettingsComposerPolishDescription,
    ),
    entry(
      general,
      l10n.generalSettingsPromptSuggestions,
      l10n.generalSettingsPromptSuggestionsDescription,
    ),
    entry(
      general,
      l10n.generalSettingsContinueLists,
      l10n.generalSettingsContinueListsDescription,
    ),
    entry(
      general,
      l10n.generalSettingsAgentModeOnly,
      l10n.generalSettingsAgentModeOnlyDescription,
    ),
    entry(
      general,
      l10n.generalSettingsSimpleModelPicker,
      l10n.generalSettingsSimpleModelPickerDescription,
    ),
    entry(
      general,
      l10n.generalSettingsLiveTurnStats,
      l10n.generalSettingsLiveTurnStatsDescription,
    ),
    entry(general, l10n.tipsSettingsTitle),
    entry(
      appearance,
      l10n.appearanceSettingsColorTheme,
      l10n.appearanceSettingsColorThemeDescription,
    ),
    entry(
      appearance,
      l10n.appearanceSettingsUiScale,
      l10n.appearanceSettingsUiScaleDescription,
    ),
    entry(
      appearance,
      l10n.appearanceSettingsUiWeight,
      l10n.appearanceSettingsUiWeightDescription,
    ),
    entry(
      appearance,
      l10n.appearanceSettingsChatWidth,
      l10n.appearanceSettingsChatWidthDescription,
    ),
    entry(
      appearance,
      l10n.appearanceSettingsChatFontSize,
      l10n.appearanceSettingsChatFontSizeDescription,
    ),
    entry(
      appearance,
      l10n.appearanceSettingsUserMessageStyle,
      l10n.appearanceSettingsUserMessageStyleDescription,
    ),
    entry(
      appearance,
      l10n.appearanceSettingsEditDetail,
      l10n.appearanceSettingsEditDetailDescription,
    ),
    entry(
      appearance,
      l10n.appearanceSettingsReplyScroll,
      l10n.appearanceSettingsReplyScrollDescription,
    ),
    entry(
      appearance,
      l10n.appearanceSettingsMusingsLanguage,
      l10n.appearanceSettingsMusingsLanguageDescription,
    ),
    entry(
      appearance,
      l10n.appearanceSettingsFoldLongMessages,
      l10n.appearanceSettingsFoldLongMessagesDescription,
    ),
    entry(
      appearance,
      l10n.appearanceSettingsExpandThinking,
      l10n.appearanceSettingsExpandThinkingDescription,
    ),
    entry(
      appearance,
      l10n.appearanceSettingsShowChangedFiles,
      l10n.appearanceSettingsShowChangedFilesDescription,
    ),
    entry(
      appearance,
      l10n.appearanceSettingsPasteCodeAsTag,
      l10n.appearanceSettingsPasteCodeAsTagDescription,
    ),
    entry(
      appearance,
      l10n.appearanceSettingsPasteLongTextAsTag,
      l10n.appearanceSettingsPasteLongTextAsTagDescription,
    ),
    entry(
      appearance,
      l10n.appearanceSettingsSidebarTimes,
      l10n.appearanceSettingsSidebarTimesDescription,
    ),
    entry(appearance, l10n.appearanceSettingsLoaderSpeed),
    entry(
      appearance,
      l10n.appearanceSettingsWindowBlur,
      l10n.appearanceSettingsWindowBlurDescription,
    ),
    entry(
      appearance,
      l10n.appearanceSettingsMinimap,
      l10n.appearanceSettingsMinimapDescription,
    ),
    entry(
      appearance,
      l10n.appearanceSettingsMinimapGlass,
      l10n.appearanceSettingsMinimapGlassDescription,
    ),
    entry(
      appearance,
      l10n.appearanceSettingsMinimapElasticity,
      l10n.appearanceSettingsMinimapElasticityDescription,
    ),
    entry(
      appearance,
      l10n.appearanceSettingsCodeFont,
      l10n.appearanceSettingsCodeFontDescription,
    ),
    entry(
      appearance,
      l10n.appearanceSettingsCodeSize,
      l10n.appearanceSettingsCodeSizeDescription,
    ),
    entry(
      appearance,
      l10n.appearanceSettingsLigatures,
      l10n.appearanceSettingsLigaturesDescription,
    ),
    entry(
      appearance,
      l10n.appearanceSettingsWordWrap,
      l10n.appearanceSettingsWordWrapDescription,
    ),
    entry(
      appearance,
      l10n.appearanceSettingsCodeMinimap,
      l10n.appearanceSettingsCodeMinimapDescription,
    ),
    entry(
      appearance,
      l10n.appearanceSettingsTerminalFont,
      l10n.appearanceSettingsTerminalFontDescription,
    ),
    entry(
      appearance,
      l10n.appearanceSettingsTerminalSize,
      l10n.appearanceSettingsTerminalSizeDescription,
    ),
    entry(
      notifications,
      l10n.notificationsEnabled,
      l10n.notificationsEnabledDescription,
    ),
    entry(
      notifications,
      l10n.notificationsWhen,
      l10n.notificationsWhenDescription,
    ),
    entry(notifications, l10n.notificationsEvents),
    entry(notifications, l10n.notificationsSound),
    entry(notifications, l10n.traySettings),
    entry(SettingsSection.stash, l10n.stashSettingsDirectory),
    entry(
      SettingsSection.stash,
      l10n.stashSettingsIssueSync,
      l10n.stashSettingsIssueSyncDescription,
    ),
    entry(network, l10n.networkProxy, l10n.networkProxyDescription),
    entry(network, l10n.networkProxyUrl, l10n.networkProxyUrlDescription),
    entry(network, l10n.networkTest, l10n.networkTestDescription),
    entry(
      browser,
      l10n.browserSettingsEnabled,
      l10n.browserSettingsEnabledDescription,
    ),
    entry(browser, l10n.browserSettingsInstall),
    entry(
      browser,
      l10n.browserSettingsStore,
      l10n.browserSettingsStoreDescription,
    ),
    entry(
      browser,
      l10n.browserSettingsUnpacked,
      l10n.browserSettingsUnpackedDescription,
    ),
    entry(browser, l10n.browserHistoryTitle),
    entry(
      browser,
      l10n.browserHistoryDetailed,
      l10n.browserHistoryDetailedDescription,
    ),
    entry(SettingsSection.updates, l10n.updateMode, l10n.updateModeDescription),
    entry(SettingsSection.updates, l10n.diagnosticsTitle),
    entry(SettingsSection.language, l10n.languageSettingsDisplayLanguage),
    entry(mobile, l10n.mobileAllow, l10n.mobileAllowDescription),
    entry(mobile, l10n.mobileDiscoverable, l10n.mobileDiscoverableDescription),
    entry(mobile, l10n.mobilePair, l10n.mobilePairDescription),
    entry(mobile, l10n.mobilePhones),
    entry(mobile, l10n.mobileGetApp, l10n.mobileGetAppDescription),
    entry(mobile, l10n.mobileRelayMode),
    entry(mobile, l10n.mobileRelayCustomAddress),
    entry(
      mobile,
      l10n.mobileDirectAddress,
      l10n.mobileDirectAddressDescription,
    ),
    entry(mobile, l10n.mobileDirectPort, l10n.mobileDirectPortDescription),
    entry(
      mobile,
      l10n.mobileThisComputerKey,
      l10n.mobileThisComputerKeyDescription,
    ),
    entry(ssh, l10n.sshSettingsServers, l10n.sshSettingsServersDescription),
    entry(
      ssh,
      l10n.sshSettingsConfigHosts,
      l10n.sshSettingsConfigHostsDescription,
    ),
    entry(SettingsSection.dataDirectory, l10n.checkpointsTitle),
    entry(SettingsSection.about, l10n.aboutChangelog),
    entry(SettingsSection.about, l10n.aboutFeedback),
    entry(SettingsSection.about, l10n.aboutWebsite),
  ];
}

/// The entries [query] finds (by label or description, any case); none for
/// an empty one.
List<SettingsEntry> searchSettings(AppLocalizations l10n, String query) {
  final words = query.trim().toLowerCase();
  if (words.isEmpty) return const [];
  return [
    for (final entry in settingsEntries(l10n))
      if (entry.label.toLowerCase().contains(words) ||
          (entry.description?.toLowerCase().contains(words) ?? false))
        entry,
  ];
}
