import 'dart:async';

import 'package:clipflow/app/providers.dart';
import 'package:clipflow/features/device_sync/domain/local_sharing_state.dart';
import 'package:clipflow/features/device_sync/domain/peer_connection_info.dart';
import 'package:clipflow/features/device_sync/domain/shared_collection_payload.dart';
import 'package:clipflow/features/device_sync/domain/shared_clipboard_payload.dart';
import 'package:clipflow/features/device_sync/services/local_sharing_service.dart';
import 'package:clipflow/features/device_sync/presentation/widgets/device_sections.dart';
import 'package:clipflow/features/settings/data/settings_repository.dart';
import 'package:clipflow/features/settings/domain/app_settings.dart';
import 'package:clipflow/features/settings/presentation/widgets/sharing_settings_section.dart';
import 'package:clipflow/l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSharingService implements LocalSharingService {
  final controller = StreamController<LocalSharingState>.broadcast();
  LocalSharingState current = const LocalSharingState();
  final peer = const PeerConnectionInfo(
    deviceId: 'macbook',
    deviceName: 'MacBook Pro',
    platform: 'macOS',
    ipAddress: '192.168.1.8',
    port: 48271,
    status: PeerConnectionStatus.discovered,
    quality: ConnectionQuality.excellent,
    latencyMs: 12,
    pendingItems: 0,
    isTrusted: false,
    isBlocked: false,
    appVersion: '1.1.5',
    protocolVersion: '1',
  );

  @override
  Stream<LocalSharingState> get states => controller.stream;

  @override
  Stream<SharedClipboardPayload> get receivedPayloads => const Stream.empty();

  @override
  Stream<SharedCollectionPayload> get receivedCollections =>
      const Stream.empty();

  @override
  Future<void> start(AppSettings settings) async {
    _emit(LocalSharingState(peers: [peer], isDiscovering: true));
  }

  @override
  Future<void> requestPairing(String deviceId) async {
    _emit(
      LocalSharingState(
        peers: [peer],
        isDiscovering: true,
        pairingSession: PairingSession(
          peer: peer.copyWith(status: PeerConnectionStatus.pairing),
          confirmationCode: '482719',
          expiresAt: DateTime.now().add(const Duration(seconds: 60)),
        ),
      ),
    );
  }

  @override
  Future<void> sendClipboard(
    String deviceId,
    SharedClipboardPayload payload,
  ) async {}

  @override
  Future<void> sendCollection(
    String deviceId,
    SharedCollectionPayload payload,
  ) async {}

  @override
  Future<void> block(String deviceId) async {}

  @override
  Future<void> cancelPairing(String deviceId) async {}

  @override
  Future<void> confirmPairing(String deviceId) async {
    final session = current.pairingSession;
    if (session == null) return;
    _emit(
      current.copyWith(
        pairingSession: PairingSession(
          peer: session.peer,
          confirmationCode: session.confirmationCode,
          expiresAt: session.expiresAt,
          isIncoming: session.isIncoming,
          isLocalConfirmed: true,
        ),
      ),
    );
  }

  @override
  Future<void> disconnect(String deviceId) async {}

  @override
  Future<void> forget(String deviceId) async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> unblock(String deviceId) async {}

  @override
  Future<void> updateConfiguration(AppSettings settings) async {}

  @override
  Future<void> dispose() => controller.close();

  void _emit(LocalSharingState state) {
    current = state;
    controller.add(state);
  }
}

void main() {
  testWidgets('shows discovered peer and the six-digit pairing code', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = SettingsRepository(
      await SharedPreferences.getInstance(),
    );
    await repository.save(
      const AppSettings(localSharingEnabled: true, language: 'vi'),
    );
    final service = _FakeSharingService();
    addTearDown(service.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(repository),
          localSharingServiceProvider.overrideWithValue(service),
        ],
        child: const CupertinoApp(
          locale: Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CupertinoPageScaffold(
            child: SingleChildScrollView(child: SharingSettingsSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MacBook Pro'), findsOneWidget);
    expect(find.text('Thiết bị đang khả dụng'.toUpperCase()), findsOneWidget);
    await tester.ensureVisible(find.text('Kết nối'));
    await tester.tap(find.text('Kết nối'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pairing-confirmation-code')), findsOneWidget);
    expect(find.text('482 719'), findsOneWidget);
    await tester.tap(find.text('Mã trùng khớp'));
    await tester.pump();
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(find.text('Đang chờ thiết bị kia…'), findsOneWidget);
  });

  testWidgets('shows manual reconnect after five failed attempts', (
    tester,
  ) async {
    var reconnectedId = '';
    final service = _FakeSharingService();
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CupertinoPageScaffold(
          child: PairedDevicesSection(
            devices: [
              service.peer.copyWith(
                status: PeerConnectionStatus.disconnected,
                quality: ConnectionQuality.offline,
                isTrusted: true,
                reconnectAttempts: 5,
                requiresManualReconnect: true,
              ),
            ],
            enabled: true,
            onDisconnect: (_) {},
            onReconnect: (id) => reconnectedId = id,
            onForget: (_) {},
            onBlock: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Kết nối lại'), findsOneWidget);
    expect(
      find.text('Không thể tự kết nối sau 5 lần. Hãy kết nối thủ công.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Kết nối lại'));
    expect(reconnectedId, 'macbook');
  });

  testWidgets(
    'allows editing device display name when local sharing is disabled',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository(
        await SharedPreferences.getInstance(),
      );
      await repository.save(
        const AppSettings(localSharingEnabled: false, language: 'vi'),
      );
      final service = _FakeSharingService();
      addTearDown(service.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(repository),
            localSharingServiceProvider.overrideWithValue(service),
          ],
          child: const CupertinoApp(
            locale: Locale('vi'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CupertinoPageScaffold(
              child: SingleChildScrollView(child: SharingSettingsSection()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textField = tester.widget<CupertinoTextField>(
        find.byType(CupertinoTextField),
      );
      expect(textField.enabled, isTrue);
    },
  );
}
