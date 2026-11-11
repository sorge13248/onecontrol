import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'screens/discovery_screen.dart';
import 'services/connection_service.dart';
import 'services/discovery_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prefer portrait orientation for comfortable trackpad grip
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final discoveryService = DiscoveryService();
  final connectionService = ConnectionService();
  await connectionService.init();

  runApp(OneControlApp(
    discoveryService: discoveryService,
    connectionService: connectionService,
  ));
}

class OneControlApp extends StatelessWidget {
  final DiscoveryService discoveryService;
  final ConnectionService connectionService;

  const OneControlApp({
    super.key,
    required this.discoveryService,
    required this.connectionService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OneControl',
      debugShowCheckedModeBanner: false,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeListResolutionCallback: (locales, supportedLocales) {
        if (locales != null) {
          for (final locale in locales) {
            if (locale.languageCode == 'it') {
              return const Locale('it');
            }
          }
        }
        return const Locale('en');
      },
      themeMode: ThemeMode.dark, // Remote controls feel great in dark mode
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1E212B),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        ),
      ),
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.light,
        ),
      ),
      home: DiscoveryScreen(
        discoveryService: discoveryService,
        connectionService: connectionService,
      ),
    );
  }
}
