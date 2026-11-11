class ClientMessage {
  static Map<String, dynamic> handshake({
    required String clientId,
    required String clientName,
    String? token,
    String? locale,
  }) =>
      {
        'type': 'handshake',
        'client_id': clientId,
        'client_name': clientName,
        'token': token,
        'locale': locale,
      };

  static Map<String, dynamic> authPin(String pin) => {
        'type': 'auth_pin',
        'pin': pin,
      };

  static Map<String, dynamic> ping() => {'type': 'ping'};

  static Map<String, dynamic> mouseMove(int dx, int dy) => {
        'type': 'mouse_move',
        'dx': dx,
        'dy': dy,
      };

  static Map<String, dynamic> mouseButton(String button, String action) => {
        'type': 'mouse_button',
        'button': button, // left, right, middle
        'action': action, // press, release, click
      };

  static Map<String, dynamic> mouseScroll(int dx, int dy) => {
        'type': 'mouse_scroll',
        'dx': dx,
        'dy': dy,
      };

  static Map<String, dynamic> keyEvent(String key, String action) => {
        'type': 'key_event',
        'key': key,
        'action': action, // down, up, press
      };

  static Map<String, dynamic> textInput(String text) => {
        'type': 'text_input',
        'text': text,
      };
}
