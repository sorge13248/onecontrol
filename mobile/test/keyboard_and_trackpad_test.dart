import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onecontrol/l10n/app_localizations.dart';
import 'package:onecontrol/models/host_device.dart';
import 'package:onecontrol/screens/remote_control_screen.dart';
import 'package:onecontrol/services/connection_service.dart';
import 'package:onecontrol/widgets/keyboard_bar_widget.dart';
import 'package:onecontrol/widgets/trackpad_widget.dart';

class MockConnectionService extends ConnectionService {
  final List<String> sentTexts = [];
  final List<String> sentKeys = [];
  final List<Offset> sentMouseMoves = [];
  final List<String> sentMouseButtons = [];
  final List<Offset> sentMouseScrolls = [];
  int disconnectCount = 0;
  bool _mockIsConnected = true;
  HostDevice? mockDevice;

  @override
  HostDevice? get activeDevice => mockDevice;

  @override
  bool get isConnected => _mockIsConnected;

  @override
  void sendTextInput(String text) {
    sentTexts.add(text);
  }

  @override
  void sendKeyEvent(String key, String action) {
    sentKeys.add('$key:$action');
  }

  @override
  void sendMouseMove(int dx, int dy) {
    sentMouseMoves.add(Offset(dx.toDouble(), dy.toDouble()));
  }

  @override
  void sendMouseButton(String button, String action) {
    sentMouseButtons.add('$button:$action');
  }

  @override
  void sendMouseScroll(int dx, int dy) {
    sentMouseScrolls.add(Offset(dx.toDouble(), dy.toDouble()));
  }

  @override
  Future<void> disconnect() async {
    disconnectCount++;
    _mockIsConnected = false;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Trackpad sensitivity persistence', () {
    testWidgets('loads and saves sensitivity per device (ip-hostname)', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'sensitivity_192.168.1.100_laptop': 2.2,
      });

      final service = MockConnectionService();
      final device = HostDevice(
        hostname: 'laptop',
        ip: '192.168.1.100',
        port: 53842,
        os: 'linux',
        version: '0.1.0',
        lastSeen: DateTime.now(),
      );

      service.mockDevice = device;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TrackpadWidget(connectionService: service)),
        ),
      );
      await tester.pumpAndSettle();

      // Sensitivity label should reflect loaded 2.2x
      expect(find.text('2.2x'), findsOneWidget);

      // Verify that changing the sensitivity updates preferences
      final slider = find.byType(Slider);
      expect(slider, findsOneWidget);

      await tester.tap(slider);
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('sensitivity_192.168.1.100_laptop'), isTrue);
    });
  });

  group('KeyboardBarWidget tests', () {
    testWidgets(
      'does not clear text at 50 chars, expands multiline and clears silently on enter',
      (WidgetTester tester) async {
        final service = MockConnectionService();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: KeyboardBarWidget(connectionService: service)),
          ),
        );
        await tester.pumpAndSettle();

        final textFieldFinder = find.byType(TextField);
        expect(textFieldFinder, findsOneWidget);

        final textField = tester.widget<TextField>(textFieldFinder);
        expect(textField.minLines, 1);
        expect(textField.maxLines, 4);
        expect(textField.keyboardType, TextInputType.multiline);

        // Enter more than 50 characters
        const longText =
            'This is a very long string with more than fifty characters to test that it does not clear!';
        await tester.enterText(textFieldFinder, longText);
        await tester.pumpAndSettle();

        // Ensure the text wasn't cleared!
        expect(find.text(longText), findsOneWidget);
        expect(service.sentTexts.join(), longText);

        // Tap the Enter button
        final enterButton = find.byTooltip('Enter');
        expect(enterButton, findsOneWidget);
        await tester.tap(enterButton);
        await tester.pumpAndSettle();

        // Text field should be empty now
        expect(find.text(longText), findsNothing);
        expect(service.sentKeys.contains('ENTER:press'), isTrue);
        // No backspaces should have been sent to host on Enter clear
        expect(
          service.sentKeys.where((k) => k.startsWith('BACKSPACE')).isEmpty,
          isTrue,
        );
      },
    );

    testWidgets('renders Italian strings when locale is it', (
      WidgetTester tester,
    ) async {
      final service = MockConnectionService();

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('it'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Column(
              children: [
                Expanded(child: TrackpadWidget(connectionService: service)),
                KeyboardBarWidget(connectionService: service),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Italian labels
      expect(find.text('Sensibilità:'), findsOneWidget);
      expect(find.text('Area Touchpad'), findsOneWidget);
      expect(find.text('Click Sinistro'), findsOneWidget);
      expect(find.text('Click Destro'), findsOneWidget);
      expect(find.byTooltip('Invio'), findsOneWidget);
    });

    testWidgets(
      'holding backspace sends continuous repeated signals and does not show tooltip',
      (WidgetTester tester) async {
        final service = MockConnectionService();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: KeyboardBarWidget(connectionService: service)),
          ),
        );
        await tester.pumpAndSettle();

        final backspaceFinder = find.byIcon(Icons.backspace_outlined);
        expect(backspaceFinder, findsOneWidget);

        // Verify no Tooltip widget wraps the backspace icon
        expect(
          find.widgetWithIcon(Tooltip, Icons.backspace_outlined),
          findsNothing,
        );

        // Touch down on the backspace button and hold
        final gesture = await tester.startGesture(
          tester.getCenter(backspaceFinder),
        );
        await tester.pump();

        // Immediately 1 backspace sent
        expect(service.sentKeys.where((k) => k == 'BACKSPACE:press').length, 1);

        // Wait 400ms (typematic delay threshold)
        await tester.pump(const Duration(milliseconds: 400));
        expect(service.sentKeys.where((k) => k == 'BACKSPACE:press').length, 1);

        // Wait 180ms (should produce 3 more repeat signals: at 460ms, 520ms, 580ms)
        await tester.pump(const Duration(milliseconds: 180));
        expect(service.sentKeys.where((k) => k == 'BACKSPACE:press').length, 4);

        // Release finger
        await gesture.up();
        await tester.pump();

        // Advance time further to ensure repeating has stopped
        await tester.pump(const Duration(milliseconds: 300));
        expect(service.sentKeys.where((k) => k == 'BACKSPACE:press').length, 4);

        // Ensure no tooltip text popped up on long press
        expect(find.text('Backspace'), findsNothing);
      },
    );
  });

  group('Trackpad gestures & right click tests', () {
    testWidgets(
      'two-finger tap triggers right click without moving cursor or scrolling',
      (WidgetTester tester) async {
        final service = MockConnectionService();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: TrackpadWidget(connectionService: service)),
          ),
        );
        await tester.pumpAndSettle();

        final trackpadFinder = find.byType(TrackpadWidget);
        final center = tester.getCenter(trackpadFinder);

        // Perform a simultaneous two-finger tap with slight natural micro-movement (< 3px)
        final p1 = await tester.startGesture(center);
        final p2 = await tester.startGesture(center + const Offset(50, 0));

        await p1.moveBy(const Offset(1, 1));
        await p2.moveBy(const Offset(0, 1));

        // Lift both fingers
        await p1.up();
        await p2.up();
        await tester.pumpAndSettle();

        // Verified: Right click is sent
        expect(service.sentMouseButtons, contains('right:click'));
        // Verified: Cursor was NOT moved
        expect(service.sentMouseMoves, isEmpty);
        // Verified: No scroll events were sent
        expect(service.sentMouseScrolls, isEmpty);
      },
    );

    testWidgets('single-finger tap triggers left click without moving cursor', (
      WidgetTester tester,
    ) async {
      final service = MockConnectionService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TrackpadWidget(connectionService: service)),
        ),
      );
      await tester.pumpAndSettle();

      final trackpadFinder = find.byType(TrackpadWidget);
      final center = tester.getCenter(trackpadFinder);

      final p1 = await tester.startGesture(center);
      await p1.moveBy(const Offset(1, 0)); // Sub-deadzone micro jitter
      await p1.up();
      await tester.pumpAndSettle();

      expect(service.sentMouseButtons, contains('left:click'));
      expect(service.sentMouseMoves, isEmpty);
    });

    testWidgets('one-finger drag past deadzone moves mouse cursor', (
      WidgetTester tester,
    ) async {
      final service = MockConnectionService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TrackpadWidget(connectionService: service)),
        ),
      );
      await tester.pumpAndSettle();

      final trackpadFinder = find.byType(TrackpadWidget);
      final center = tester.getCenter(trackpadFinder);

      final p1 = await tester.startGesture(center);
      await p1.moveBy(const Offset(40, 20));
      await p1.up();
      await tester.pumpAndSettle();

      expect(service.sentMouseMoves.isNotEmpty, isTrue);
      // Tap click should not be triggered after drag
      expect(service.sentMouseButtons, isEmpty);
    });
  });

  group('RemoteControlScreen navigation tests', () {
    testWidgets(
      'clicking back in AppBar disconnects and returns to previous screen without popping twice',
      (WidgetTester tester) async {
        final service = MockConnectionService();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            RemoteControlScreen(connectionService: service),
                      ),
                    );
                  },
                  child: const Text('Open Remote'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open remote screen
        await tester.tap(find.text('Open Remote'));
        await tester.pumpAndSettle();
        expect(find.byType(RemoteControlScreen), findsOneWidget);

        // Tap the back button in AppBar
        final backButton = find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.arrow_back),
        );
        expect(backButton, findsOneWidget);
        await tester.tap(backButton);
        await tester.pumpAndSettle();

        // Verify RemoteControlScreen is popped and the base screen is still present (not empty)
        expect(find.byType(RemoteControlScreen), findsNothing);
        expect(find.text('Open Remote'), findsOneWidget);
        expect(service.disconnectCount, 1);
      },
    );

    testWidgets(
      'system back gesture disconnects cleanly and returns to previous screen',
      (WidgetTester tester) async {
        final service = MockConnectionService();
        final navKey = GlobalKey<NavigatorState>();

        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navKey,
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            RemoteControlScreen(connectionService: service),
                      ),
                    );
                  },
                  child: const Text('Open Remote'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Remote'));
        await tester.pumpAndSettle();
        expect(find.byType(RemoteControlScreen), findsOneWidget);

        // Trigger system back pop
        await navKey.currentState!.maybePop();
        await tester.pumpAndSettle();

        expect(find.byType(RemoteControlScreen), findsNothing);
        expect(find.text('Open Remote'), findsOneWidget);
        expect(service.disconnectCount, 1);
      },
    );
  });
}
