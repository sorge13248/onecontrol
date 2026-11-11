import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Standard Flutter internationalization class supporting English (default)
/// and Italian (automatically detected based on OS language).
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('it'),
  ];

  bool get isItalian => locale.languageCode == 'it';

  // --- Discovery Screen ---
  String get appTitle => 'OneControl';
  String get pcPairing => isItalian ? 'Associazione PC' : 'PC Pairing';
  String get pcPairingPrompt => isItalian
      ? 'Sul PC è comparsa una notifica con un PIN a 6 cifre. Inseriscilo qui per autorizzare la connessione:'
      : 'A notification with a 6-digit PIN has appeared on the PC. Enter it here to authorize the connection:';
  String get cancel => isItalian ? 'Annulla' : 'Cancel';
  String get confirmPin => isItalian ? 'Conferma PIN' : 'Confirm PIN';
  String get manualConnection => isItalian ? 'Connessione Manuale' : 'Manual Connection';
  String get hostIpAddress => isItalian ? 'Indirizzo IP Host' : 'Host IP Address';
  String get hostIpHint => isItalian ? 'es. 192.168.1.100' : 'e.g. 192.168.1.100';
  String get port => isItalian ? 'Porta' : 'Port';
  String get connect => isItalian ? 'Connetti' : 'Connect';
  String get addPcManually => isItalian ? 'Aggiungi PC Manualmente' : 'Add PC Manually';
  String get refreshScan => isItalian ? 'Ricarica scansione' : 'Refresh scan';
  String get searchingLan => isItalian
      ? 'Ricerca PC nella rete locale (LAN)...'
      : 'Searching for PCs on local network (LAN)...';
  String get noPcsFound => isItalian ? 'Nessun PC trovato nella rete' : 'No PCs found on the network';
  String get ensureDaemonRunning => isItalian
      ? 'Assicurati che il demone OneControl sia avviato sul PC e che la porta 53842 sia aperta sul firewall.'
      : 'Ensure the OneControl daemon is running on the PC and port 53842 is open in the firewall.';
  String get enterIpManually => isItalian ? 'Inserisci IP manualmente' : 'Enter IP manually';

  // --- Remote Control Screen ---
  String get remoteControl => isItalian ? 'Controllo Remoto' : 'Remote Control';
  String get connected => isItalian ? 'Connesso' : 'Connected';
  String get disconnect => isItalian ? 'Disconnetti' : 'Disconnect';

  // --- Keyboard & Controls ---
  String get openSoftwareKeyboard => isItalian ? 'Apri Tastiera Software' : 'Open Software Keyboard';
  String get typeToSend => isItalian ? 'Digita qui per inviare al PC...' : 'Type here to send to PC...';
  String get clearText => isItalian ? 'Cancella testo' : 'Clear text';
  String get backspace => 'Backspace';
  String get enter => isItalian ? 'Invio' : 'Enter';
  String get mute => isItalian ? 'Muto' : 'Mute';
  String get volumeDown => isItalian ? 'Volume -' : 'Volume -';
  String get volumeUp => isItalian ? 'Volume +' : 'Volume +';
  String get playPause => isItalian ? 'Play/Pausa' : 'Play/Pause';

  // --- Trackpad ---
  String get sensitivity => isItalian ? 'Sensibilità:' : 'Sensitivity:';
  String get touchpadArea => isItalian ? 'Area Touchpad' : 'Touchpad Area';
  String get touchpadInstructions => isItalian
      ? '1 dito: sposta cursore | Tap: click sinistro\n2 dita: scroll | Tap 2 dita: click destro'
      : '1 finger: move cursor | Tap: left click\n2 fingers: scroll | 2-finger tap: right click';
  String get leftClick => isItalian ? 'Click Sinistro' : 'Left Click';
  String get middleClick => isItalian ? 'Click Centrale (Rotella)' : 'Middle Click (Wheel)';
  String get rightClick => isItalian ? 'Click Destro' : 'Right Click';

  // --- Connection Status Messages ---
  String get statusDisconnected => isItalian ? 'Disconnesso' : 'Disconnected';
  String statusConnecting(String host) => isItalian ? 'Connessione a $host...' : 'Connecting to $host...';
  String get statusAuthenticating => isItalian ? 'Autenticazione in corso...' : 'Authenticating...';
  String statusConnectionError(String err) => isItalian ? 'Errore di connessione: $err' : 'Connection error: $err';
  String get statusDisconnectedFromServer => isItalian ? 'Disconnesso dal server' : 'Disconnected from server';
  String statusUnableToConnect(String err) => isItalian ? 'Impossibile connettersi: $err' : 'Unable to connect: $err';
  String statusConnectedTo(String host) => isItalian ? 'Connesso a $host' : 'Connected to $host';
  String get statusEnterPinPrompt => isItalian ? 'Inserisci il PIN mostrato sul PC' : 'Enter the PIN shown on the PC';
  String get statusConnectionRefused => isItalian ? 'Connessione rifiutata' : 'Connection refused';
  String get statusPairingCompleted => isItalian ? 'Associazione completata! Connesso.' : 'Pairing completed! Connected.';
  String get statusIncorrectPin => isItalian ? 'PIN errato. Riprova.' : 'Incorrect PIN. Try again.';
  String statusServerError(String msg) => isItalian ? 'Errore dal server: $msg' : 'Server error: $msg';
  String get statusVerifyingPin => isItalian ? 'Verifica PIN in corso...' : 'Verifying PIN...';
  String manualHost(String ip) => isItalian ? 'PC ($ip)' : 'PC ($ip)';
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'it'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
