import 'dart:convert';

enum DuplicateBehavior { bringToTop, createNew, keepPosition }

class AppSettings {
  const AppSettings({
    this.hasCompletedOnboarding = false,
    this.monitoringEnabled = true,
    this.openAtLogin = false,
    this.runInTray = true,
    this.showInDock = true,
    this.closeAfterCopy = false,
    this.soundEnabled = true,
    this.themeMode = 'system',
    this.accentColor = 'indigo',
    this.language = 'vi',
    this.targetTranslationLanguage = 'vi',
    this.ignoreDuplicates = true,
    this.ignoreSensitive = true,
    this.ignoreOtp = true,
    this.ignoreLongToken = true,
    this.minTextLength = 1,
    this.maxTextLength = 100000,
    this.maxImageMb = 20,
    this.retentionDays = 30,
    this.maxItems = 5000,
    this.maxDatabaseMb = 512,
    this.deleteImagesFirst = true,
    this.protectPinned = true,
    this.protectCollections = true,
    this.shortcut = '⌃V',
    this.openPanelShortcut,
    this.focusSearchShortcut,
    this.togglePinShortcut,
    this.deleteItemShortcut,
    this.duplicateBehavior = DuplicateBehavior.bringToTop,
    this.allowedTypes = const {
      'text',
      'url',
      'email',
      'phone',
      'code',
      'color',
      'json',
      'file',
      'image',
    },
    this.excludedApplications = const ['1Password', 'Keychain Access'],
  });

  final bool hasCompletedOnboarding;
  final bool monitoringEnabled;
  final bool openAtLogin;
  final bool runInTray;
  final bool showInDock;
  final bool closeAfterCopy;
  final bool soundEnabled;
  final String themeMode;
  final String accentColor;
  final String language;
  final String targetTranslationLanguage;
  final bool ignoreDuplicates;
  final bool ignoreSensitive;
  final bool ignoreOtp;
  final bool ignoreLongToken;
  final int minTextLength;
  final int maxTextLength;
  final int maxImageMb;
  final int retentionDays;
  final int maxItems;
  final int maxDatabaseMb;
  final bool deleteImagesFirst;
  final bool protectPinned;
  final bool protectCollections;
  final String shortcut;
  final String? openPanelShortcut;
  final String? focusSearchShortcut;
  final String? togglePinShortcut;
  final String? deleteItemShortcut;
  final DuplicateBehavior duplicateBehavior;
  final Set<String> allowedTypes;
  final List<String> excludedApplications;

  AppSettings copyWith({
    bool? hasCompletedOnboarding,
    bool? monitoringEnabled,
    bool? openAtLogin,
    bool? runInTray,
    bool? showInDock,
    bool? closeAfterCopy,
    bool? soundEnabled,
    String? themeMode,
    String? accentColor,
    String? language,
    String? targetTranslationLanguage,
    bool? ignoreDuplicates,
    bool? ignoreSensitive,
    bool? ignoreOtp,
    bool? ignoreLongToken,
    int? minTextLength,
    int? maxTextLength,
    int? maxImageMb,
    int? retentionDays,
    int? maxItems,
    int? maxDatabaseMb,
    bool? deleteImagesFirst,
    bool? protectPinned,
    bool? protectCollections,
    String? shortcut,
    String? openPanelShortcut,
    String? focusSearchShortcut,
    String? togglePinShortcut,
    String? deleteItemShortcut,
    DuplicateBehavior? duplicateBehavior,
    Set<String>? allowedTypes,
    List<String>? excludedApplications,
  }) {
    return AppSettings(
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      monitoringEnabled: monitoringEnabled ?? this.monitoringEnabled,
      openAtLogin: openAtLogin ?? this.openAtLogin,
      runInTray: runInTray ?? this.runInTray,
      showInDock: showInDock ?? this.showInDock,
      closeAfterCopy: closeAfterCopy ?? this.closeAfterCopy,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
      language: language ?? this.language,
      targetTranslationLanguage:
          targetTranslationLanguage ?? this.targetTranslationLanguage,
      ignoreDuplicates: ignoreDuplicates ?? this.ignoreDuplicates,
      ignoreSensitive: ignoreSensitive ?? this.ignoreSensitive,
      ignoreOtp: ignoreOtp ?? this.ignoreOtp,
      ignoreLongToken: ignoreLongToken ?? this.ignoreLongToken,
      minTextLength: minTextLength ?? this.minTextLength,
      maxTextLength: maxTextLength ?? this.maxTextLength,
      maxImageMb: maxImageMb ?? this.maxImageMb,
      retentionDays: retentionDays ?? this.retentionDays,
      maxItems: maxItems ?? this.maxItems,
      maxDatabaseMb: maxDatabaseMb ?? this.maxDatabaseMb,
      deleteImagesFirst: deleteImagesFirst ?? this.deleteImagesFirst,
      protectPinned: protectPinned ?? this.protectPinned,
      protectCollections: protectCollections ?? this.protectCollections,
      shortcut: shortcut ?? this.shortcut,
      openPanelShortcut: openPanelShortcut ?? this.openPanelShortcut,
      focusSearchShortcut: focusSearchShortcut ?? this.focusSearchShortcut,
      togglePinShortcut: togglePinShortcut ?? this.togglePinShortcut,
      deleteItemShortcut: deleteItemShortcut ?? this.deleteItemShortcut,
      duplicateBehavior: duplicateBehavior ?? this.duplicateBehavior,
      allowedTypes: allowedTypes ?? this.allowedTypes,
      excludedApplications: excludedApplications ?? this.excludedApplications,
    );
  }

  String toJson() => jsonEncode({
    'hasCompletedOnboarding': hasCompletedOnboarding,
    'monitoringEnabled': monitoringEnabled,
    'openAtLogin': openAtLogin,
    'runInTray': runInTray,
    'showInDock': showInDock,
    'closeAfterCopy': closeAfterCopy,
    'soundEnabled': soundEnabled,
    'themeMode': themeMode,
    'accentColor': accentColor,
    'language': language,
    'targetTranslationLanguage': targetTranslationLanguage,
    'ignoreDuplicates': ignoreDuplicates,
    'ignoreSensitive': ignoreSensitive,
    'ignoreOtp': ignoreOtp,
    'ignoreLongToken': ignoreLongToken,
    'minTextLength': minTextLength,
    'maxTextLength': maxTextLength,
    'maxImageMb': maxImageMb,
    'retentionDays': retentionDays,
    'maxItems': maxItems,
    'maxDatabaseMb': maxDatabaseMb,
    'deleteImagesFirst': deleteImagesFirst,
    'protectPinned': protectPinned,
    'protectCollections': protectCollections,
    'shortcut': shortcut,
    'openPanelShortcut': openPanelShortcut,
    'focusSearchShortcut': focusSearchShortcut,
    'togglePinShortcut': togglePinShortcut,
    'deleteItemShortcut': deleteItemShortcut,
    'duplicateBehavior': duplicateBehavior.name,
    'allowedTypes': allowedTypes.toList(),
    'excludedApplications': excludedApplications,
  });

  factory AppSettings.fromJson(String source) {
    final map = jsonDecode(source) as Map<String, dynamic>;
    final defaults = const AppSettings();
    T value<T>(String key, T fallback) => (map[key] as T?) ?? fallback;
    final allowedTypes = map['allowedTypes'] is List
        ? (map['allowedTypes'] as List).cast<String>().toSet()
        : defaults.allowedTypes;
    final excludedApplications = map['excludedApplications'] is List
        ? (map['excludedApplications'] as List).cast<String>()
        : defaults.excludedApplications;
    return AppSettings(
      hasCompletedOnboarding: value('hasCompletedOnboarding', false),
      monitoringEnabled: value('monitoringEnabled', true),
      openAtLogin: value('openAtLogin', false),
      runInTray: value('runInTray', true),
      showInDock: value('showInDock', true),
      closeAfterCopy: value('closeAfterCopy', false),
      soundEnabled: value('soundEnabled', true),
      themeMode: value('themeMode', 'system'),
      accentColor: value('accentColor', 'indigo'),
      language: value('language', 'vi'),
      targetTranslationLanguage: value('targetTranslationLanguage', 'vi'),
      ignoreDuplicates: value('ignoreDuplicates', true),
      ignoreSensitive: value('ignoreSensitive', true),
      ignoreOtp: value('ignoreOtp', true),
      ignoreLongToken: value('ignoreLongToken', true),
      minTextLength: value('minTextLength', 1),
      maxTextLength: value('maxTextLength', 100000),
      maxImageMb: value('maxImageMb', 20),
      retentionDays: value('retentionDays', 30),
      maxItems: value('maxItems', 5000),
      maxDatabaseMb: value('maxDatabaseMb', 512),
      deleteImagesFirst: value('deleteImagesFirst', true),
      protectPinned: value('protectPinned', true),
      protectCollections: value('protectCollections', true),
      shortcut: value('shortcut', '⌃V'),
      openPanelShortcut: map['openPanelShortcut'] as String?,
      focusSearchShortcut: map['focusSearchShortcut'] as String?,
      togglePinShortcut: map['togglePinShortcut'] as String?,
      deleteItemShortcut: map['deleteItemShortcut'] as String?,
      duplicateBehavior: DuplicateBehavior.values.firstWhere(
        (item) => item.name == map['duplicateBehavior'],
        orElse: () => DuplicateBehavior.bringToTop,
      ),
      allowedTypes: allowedTypes,
      excludedApplications: excludedApplications,
    );
  }
}
