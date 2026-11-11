import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/host_device.dart';
import '../models/protocol_messages.dart';

enum ConnectionStateStatus {
  disconnected,
  connecting,
  handshaking,
  pinRequired,
  connected,
  error,
}

class ConnectionService extends ChangeNotifier {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;

  HostDevice? _activeDevice;
  ConnectionStateStatus _status = ConnectionStateStatus.disconnected;
  late String _statusMessage;
  String? _clientId;
  String _clientName = 'Smartphone';

  ConnectionService() {
    _statusMessage = _isItalian ? 'Disconnesso' : 'Disconnected';
  }

  bool get _isItalian {
    try {
      return Platform.localeName.toLowerCase().startsWith('it');
    } catch (_) {
      return false;
    }
  }

  String get osLanguageCode => _isItalian ? 'it' : 'en';

  HostDevice? get activeDevice => _activeDevice;
  ConnectionStateStatus get status => _status;
  String get statusMessage => _statusMessage;
  bool get isConnected => _status == ConnectionStateStatus.connected;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _clientId = prefs.getString('onecontrol_client_id');
    if (_clientId == null) {
      _clientId = 'client_${Random().nextInt(899999) + 100000}';
      await prefs.setString('onecontrol_client_id', _clientId!);
    }
    _clientName = Platform.isAndroid ? 'Android Phone' : (Platform.isIOS ? 'iPhone' : 'OneControl Client');
  }

  Future<void> connect(HostDevice device) async {
    await disconnect();
    _activeDevice = device;
    _updateStatus(
      ConnectionStateStatus.connecting,
      _isItalian ? 'Connessione a ${device.hostname}...' : 'Connecting to ${device.hostname}...',
    );

    try {
      if (_clientId == null) await init();

      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('token_${device.id}');

      final uri = Uri.parse('ws://${device.ip}:${device.port}');
      _channel = WebSocketChannel.connect(uri);
      await _channel?.ready;

      _updateStatus(
        ConnectionStateStatus.handshaking,
        _isItalian ? 'Autenticazione in corso...' : 'Authenticating...',
      );

      _subscription = _channel?.stream.listen(
        _handleServerMessage,
        onError: (err) {
          _updateStatus(
            ConnectionStateStatus.error,
            _isItalian ? 'Errore di connessione: $err' : 'Connection error: $err',
          );
          _cleanup();
        },
        onDone: () {
          if (_status != ConnectionStateStatus.disconnected) {
            _updateStatus(
              ConnectionStateStatus.disconnected,
              _isItalian ? 'Disconnesso dal server' : 'Disconnected from server',
            );
          }
          _cleanup();
        },
      );

      // Send handshake with detected OS locale
      final handshake = ClientMessage.handshake(
        clientId: _clientId!,
        clientName: _clientName,
        token: savedToken,
        locale: osLanguageCode,
      );
      _sendRaw(handshake);

      // Start ping keepalive
      _pingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (_status == ConnectionStateStatus.connected) {
          _sendRaw(ClientMessage.ping());
        }
      });
    } catch (e) {
      _updateStatus(
        ConnectionStateStatus.error,
        _isItalian ? 'Impossibile connettersi: $e' : 'Unable to connect: $e',
      );
      _cleanup();
    }
  }

  void _handleServerMessage(dynamic raw) {
    try {
      final json = jsonDecode(raw as String);
      if (json is! Map<String, dynamic>) return;

      final type = json['type'] as String?;
      switch (type) {
        case 'handshake_ack':
          final authStatus = json['status'] as String?;
          if (authStatus == 'authenticated') {
            final serverMsg = json['message'] as String?;
            _updateStatus(
              ConnectionStateStatus.connected,
              serverMsg ?? (_isItalian ? 'Connesso a ${_activeDevice?.hostname}' : 'Connected to ${_activeDevice?.hostname}'),
            );
          } else if (authStatus == 'need_pin') {
            final serverMsg = json['message'] as String?;
            _updateStatus(
              ConnectionStateStatus.pinRequired,
              serverMsg ?? (_isItalian ? 'Inserisci il PIN mostrato sul PC' : 'Enter the PIN shown on the PC'),
            );
          } else {
            _updateStatus(
              ConnectionStateStatus.error,
              json['message'] ?? (_isItalian ? 'Connessione rifiutata' : 'Connection refused'),
            );
          }
          break;

        case 'auth_ack':
          final success = json['success'] as bool? ?? false;
          if (success) {
            final token = json['token'] as String?;
            if (token != null && _activeDevice != null) {
              SharedPreferences.getInstance().then((prefs) {
                prefs.setString('token_${_activeDevice!.id}', token);
              });
            }
            final serverMsg = json['message'] as String?;
            _updateStatus(
              ConnectionStateStatus.connected,
              serverMsg ?? (_isItalian ? 'Associazione completata! Connesso.' : 'Pairing completed! Connected.'),
            );
          } else {
            final serverMsg = json['message'] as String?;
            _updateStatus(
              ConnectionStateStatus.pinRequired,
              serverMsg ?? (_isItalian ? 'PIN errato. Riprova.' : 'Incorrect PIN. Try again.'),
            );
          }
          break;

        case 'pong':
          // Keepalive OK
          break;

        case 'error':
          final msg = json['message'] as String? ?? (_isItalian ? 'Errore dal server' : 'Server error');
          _updateStatus(ConnectionStateStatus.error, msg);
          break;
      }
    } catch (e) {
      debugPrint('Error parsing server message: $e');
    }
  }

  void submitPin(String pin) {
    if (_channel != null) {
      _sendRaw(ClientMessage.authPin(pin));
      _updateStatus(
        ConnectionStateStatus.handshaking,
        _isItalian ? 'Verifica PIN in corso...' : 'Verifying PIN...',
      );
    }
  }

  void sendMouseMove(int dx, int dy) {
    if (_status == ConnectionStateStatus.connected) {
      _sendRaw(ClientMessage.mouseMove(dx, dy));
    }
  }

  void sendMouseButton(String button, String action) {
    if (_status == ConnectionStateStatus.connected) {
      _sendRaw(ClientMessage.mouseButton(button, action));
    }
  }

  void sendMouseScroll(int dx, int dy) {
    if (_status == ConnectionStateStatus.connected) {
      _sendRaw(ClientMessage.mouseScroll(dx, dy));
    }
  }

  void sendKeyEvent(String key, String action) {
    if (_status == ConnectionStateStatus.connected) {
      _sendRaw(ClientMessage.keyEvent(key, action));
    }
  }

  void sendTextInput(String text) {
    if (_status == ConnectionStateStatus.connected) {
      _sendRaw(ClientMessage.textInput(text));
    }
  }

  void _sendRaw(Map<String, dynamic> data) {
    try {
      _channel?.sink.add(jsonEncode(data));
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  void _updateStatus(ConnectionStateStatus newStatus, String msg) {
    _status = newStatus;
    _statusMessage = msg;
    notifyListeners();
  }

  void _cleanup() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
  }

  Future<void> disconnect() async {
    _cleanup();
    _activeDevice = null;
    _updateStatus(
      ConnectionStateStatus.disconnected,
      _isItalian ? 'Disconnesso' : 'Disconnected',
    );
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
