import 'dart:convert';

enum DuplicateBehavior { bringToTop, createNew, keepPosition }

class AppSettings {
  static const defaultAiModel = 'gemma-4-e2b';

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
    this.cloudImageHost = 'freeimage',
    this.freeImageApiKey = '6d207e02198a847aa98d0a2a901485a5',
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
    this.aiEnabled = true,
    this.selectedAiModel = defaultAiModel,
    this.localSharingEnabled = false,
    this.deviceDiscoverable = true,
    this.autoConnectTrustedDevices = true,
    this.autoSyncClipboard = true,
    this.syncPinnedItemsOnly = false,
    this.allowReceivingImages = true,
    this.sharingMaxImageMb = 20,
    this.notifyDeviceConnected = true,
    this.notifyClipboardReceived = false,
    this.allConnectionsPaused = false,
    this.deviceDisplayName = '',
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
  final bool aiEnabled;
  final String selectedAiModel;
  final bool localSharingEnabled;
  final bool deviceDiscoverable;
  final bool autoConnectTrustedDevices;
  final bool autoSyncClipboard;
  final bool syncPinnedItemsOnly;
  final bool allowReceivingImages;
  final int sharingMaxImageMb;
  final bool notifyDeviceConnected;
  final bool notifyClipboardReceived;
  final bool allConnectionsPaused;
  final String deviceDisplayName;
  final String themeMode;
  final String accentColor;
  final String language;
  final String targetTranslationLanguage;
  final String cloudImageHost;
  final String freeImageApiKey;
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
    bool? aiEnabled,
    String? selectedAiModel,
    bool? localSharingEnabled,
    bool? deviceDiscoverable,
    bool? autoConnectTrustedDevices,
    bool? autoSyncClipboard,
    bool? syncPinnedItemsOnly,
    bool? allowReceivingImages,
    int? sharingMaxImageMb,
    bool? notifyDeviceConnected,
    bool? notifyClipboardReceived,
    bool? allConnectionsPaused,
    String? deviceDisplayName,
    String? themeMode,
    String? accentColor,
    String? language,
    String? targetTranslationLanguage,
    String? cloudImageHost,
    String? freeImageApiKey,
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
      aiEnabled: aiEnabled ?? this.aiEnabled,
      selectedAiModel: selectedAiModel ?? this.selectedAiModel,
      localSharingEnabled: localSharingEnabled ?? this.localSharingEnabled,
      deviceDiscoverable: deviceDiscoverable ?? this.deviceDiscoverable,
      autoConnectTrustedDevices:
          autoConnectTrustedDevices ?? this.autoConnectTrustedDevices,
      autoSyncClipboard: autoSyncClipboard ?? this.autoSyncClipboard,
      syncPinnedItemsOnly: syncPinnedItemsOnly ?? this.syncPinnedItemsOnly,
      allowReceivingImages: allowReceivingImages ?? this.allowReceivingImages,
      sharingMaxImageMb: sharingMaxImageMb ?? this.sharingMaxImageMb,
      notifyDeviceConnected:
          notifyDeviceConnected ?? this.notifyDeviceConnected,
      notifyClipboardReceived:
          notifyClipboardReceived ?? this.notifyClipboardReceived,
      allConnectionsPaused: allConnectionsPaused ?? this.allConnectionsPaused,
      deviceDisplayName: deviceDisplayName ?? this.deviceDisplayName,
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
      language: language ?? this.language,
      targetTranslationLanguage:
          targetTranslationLanguage ?? this.targetTranslationLanguage,
      cloudImageHost: cloudImageHost ?? this.cloudImageHost,
      freeImageApiKey: freeImageApiKey ?? this.freeImageApiKey,
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
    'aiEnabled': aiEnabled,
    'selectedAiModel': selectedAiModel,
    'localSharingEnabled': localSharingEnabled,
    'deviceDiscoverable': deviceDiscoverable,
    'autoConnectTrustedDevices': autoConnectTrustedDevices,
    'autoSyncClipboard': autoSyncClipboard,
    'syncPinnedItemsOnly': syncPinnedItemsOnly,
    'allowReceivingImages': allowReceivingImages,
    'sharingMaxImageMb': sharingMaxImageMb,
    'notifyDeviceConnected': notifyDeviceConnected,
    'notifyClipboardReceived': notifyClipboardReceived,
    'allConnectionsPaused': allConnectionsPaused,
    'deviceDisplayName': deviceDisplayName,
    'themeMode': themeMode,
    'accentColor': accentColor,
    'language': language,
    'targetTranslationLanguage': targetTranslationLanguage,
    'cloudImageHost': cloudImageHost,
    'freeImageApiKey': freeImageApiKey,
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
    final storedAiModel = map['selectedAiModel'] as String?;
    final selectedAiModel =
        storedAiModel == null || storedAiModel.trim().isEmpty
        ? defaultAiModel
        : storedAiModel;
    return AppSettings(
      hasCompletedOnboarding: value('hasCompletedOnboarding', false),
      monitoringEnabled: value('monitoringEnabled', true),
      openAtLogin: value('openAtLogin', false),
      runInTray: value('runInTray', true),
      showInDock: value('showInDock', true),
      closeAfterCopy: value('closeAfterCopy', false),
      soundEnabled: value('soundEnabled', true),
      aiEnabled: value('aiEnabled', true),
      selectedAiModel: selectedAiModel,
      localSharingEnabled: value('localSharingEnabled', false),
      deviceDiscoverable: value('deviceDiscoverable', true),
      autoConnectTrustedDevices: value('autoConnectTrustedDevices', true),
      autoSyncClipboard: value('autoSyncClipboard', true),
      syncPinnedItemsOnly: value('syncPinnedItemsOnly', false),
      allowReceivingImages: value('allowReceivingImages', true),
      sharingMaxImageMb: value('sharingMaxImageMb', 20),
      notifyDeviceConnected: value('notifyDeviceConnected', true),
      notifyClipboardReceived: value('notifyClipboardReceived', false),
      allConnectionsPaused: value('allConnectionsPaused', false),
      deviceDisplayName: value('deviceDisplayName', ''),
      themeMode: value('themeMode', 'system'),
      accentColor: value('accentColor', 'indigo'),
      language: value('language', 'en'),
      targetTranslationLanguage: value('targetTranslationLanguage', 'vi'),
      cloudImageHost: value('cloudImageHost', 'freeimage'),
      freeImageApiKey: value(
        'freeImageApiKey',
        '6d207e02198a847aa98d0a2a901485a5',
      ),
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
