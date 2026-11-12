import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onecontrol/main.dart';
import 'package:onecontrol/services/connection_service.dart';
import 'package:onecontrol/services/discovery_service.dart';

void main() {
  testWidgets('OneControl app smoke test (English default)', (
    WidgetTester tester,
  ) async {
    final discoveryService = DiscoveryService();
    final connectionService = ConnectionService();

    await tester.pumpWidget(
      OneControlApp(
        discoveryService: discoveryService,
        connectionService: connectionService,
      ),
    );

    // Verify that the title 'OneControl' is present
    expect(find.text('OneControl'), findsOneWidget);
    // Verify English text by default
    expect(
      find.text('Searching for PCs on local network (LAN)...'),
      findsOneWidget,
    );

    discoveryService.stopDiscovery();
    connectionService.disconnect();
  });

  testWidgets('OneControl app detects Italian system locale', (
    WidgetTester tester,
  ) async {
    final discoveryService = DiscoveryService();
    final connectionService = ConnectionService();

    // Simulate Italian OS locale
    tester.platformDispatcher.localesTestValue = [const Locale('it', 'IT')];

    await tester.pumpWidget(
      OneControlApp(
        discoveryService: discoveryService,
        connectionService: connectionService,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('OneControl'), findsOneWidget);
    // Verify automatic Italian localization
    expect(find.text('Ricerca PC nella rete locale (LAN)...'), findsOneWidget);
    expect(find.text('Nessun PC trovato nella rete'), findsOneWidget);

    tester.platformDispatcher.clearLocalesTestValue();
    discoveryService.stopDiscovery();
    connectionService.disconnect();
  });

  testWidgets('Discovery pauses on app background and resumes on foreground', (
    WidgetTester tester,
  ) async {
    final discoveryService = DiscoveryService();
    final connectionService = ConnectionService();

    await tester.pumpWidget(
      OneControlApp(
        discoveryService: discoveryService,
        connectionService: connectionService,
      ),
    );
    await tester.pump();

    expect(discoveryService.isScanning, isTrue);

    // Simulate app going to background / locked
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(discoveryService.isScanning, isFalse);

    // Simulate app returning to foreground / unlocked
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(discoveryService.isScanning, isTrue);

    // Test manual refresh button
    final refreshBtn = find.byTooltip('Refresh scan');
    expect(refreshBtn, findsOneWidget);
    await tester.tap(refreshBtn);
    await tester.pump();
    expect(discoveryService.isScanning, isTrue);

    discoveryService.stopDiscovery();
    connectionService.disconnect();
  });

  testWidgets('Discovery pauses on app background and resumes on foreground', (
    WidgetTester tester,
  ) async {
    final discoveryService = DiscoveryService();
    final connectionService = ConnectionService();

    await tester.pumpWidget(
      OneControlApp(
        discoveryService: discoveryService,
        connectionService: connectionService,
      ),
    );
    await tester.pump();

    expect(discoveryService.isScanning, isTrue);

    // Simulate app going to background / locked
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(discoveryService.isScanning, isFalse);

    // Simulate app returning to foreground / unlocked
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(discoveryService.isScanning, isTrue);

    // Test manual refresh button
    final refreshBtn = find.byTooltip('Refresh scan');
    expect(refreshBtn, findsOneWidget);
    await tester.tap(refreshBtn);
    await tester.pump();
    expect(discoveryService.isScanning, isTrue);

    discoveryService.stopDiscovery();
    connectionService.disconnect();
  });
}
