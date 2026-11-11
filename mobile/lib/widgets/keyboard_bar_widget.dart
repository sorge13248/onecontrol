import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/connection_service.dart';

class KeyboardBarWidget extends StatefulWidget {
  final ConnectionService connectionService;

  const KeyboardBarWidget({super.key, required this.connectionService});

  @override
  State<KeyboardBarWidget> createState() => _KeyboardBarWidgetState();
}

class _KeyboardBarWidgetState extends State<KeyboardBarWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _previousText = '';
  bool _suppressTextSync = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _clearControllerSilently() {
    _suppressTextSync = true;
    _controller.clear();
    _previousText = '';
    _suppressTextSync = false;
    if (mounted) {
      setState(() {});
    }
  }

  void _onTextChanged() {
    if (_suppressTextSync) return;

    final currentText = _controller.text;
    if (currentText == _previousText) return;

    // Find common prefix
    int prefixLen = 0;
    final minLen = currentText.length < _previousText.length
        ? currentText.length
        : _previousText.length;
    while (prefixLen < minLen &&
        currentText.codeUnitAt(prefixLen) ==
            _previousText.codeUnitAt(prefixLen)) {
      prefixLen++;
    }

    // Find common suffix
    int suffixLen = 0;
    while (suffixLen < (minLen - prefixLen) &&
        currentText.codeUnitAt(currentText.length - 1 - suffixLen) ==
            _previousText.codeUnitAt(_previousText.length - 1 - suffixLen)) {
      suffixLen++;
    }

    final deletedCount = _previousText.length - prefixLen - suffixLen;
    final insertedText = currentText.substring(
      prefixLen,
      currentText.length - suffixLen,
    );

    // Send backspaces for deleted characters
    for (int i = 0; i < deletedCount; i++) {
      widget.connectionService.sendKeyEvent('BACKSPACE', 'press');
    }

    // Send new characters
    if (insertedText.isNotEmpty) {
      widget.connectionService.sendTextInput(insertedText);
    }

    final hasTextNow = currentText.isNotEmpty;
    final hadTextBefore = _previousText.isNotEmpty;
    _previousText = currentText;

    if (hasTextNow != hadTextBefore && mounted) {
      setState(() {});
    }
  }

  void _sendEnter() {
    HapticFeedback.lightImpact();
    widget.connectionService.sendKeyEvent('ENTER', 'press');
    _clearControllerSilently();
  }

  void _sendBackspace() {
    HapticFeedback.lightImpact();
    if (_controller.text.isNotEmpty) {
      final text = _controller.text;
      final selection = _controller.selection;
      if (selection.isValid && !selection.isCollapsed) {
        final start = selection.start;
        final end = selection.end;
        final newText = text.substring(0, start) + text.substring(end);
        _controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: start),
        );
      } else if (selection.isValid && selection.baseOffset > 0) {
        final pos = selection.baseOffset;
        final newText = text.substring(0, pos - 1) + text.substring(pos);
        _controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: pos - 1),
        );
      } else {
        final newText = text.substring(0, text.length - 1);
        _controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newText.length),
        );
      }
    } else {
      widget.connectionService.sendKeyEvent('BACKSPACE', 'press');
    }
  }

  Timer? _backspaceDelayTimer;
  Timer? _backspaceRepeatTimer;

  void _startBackspaceRepeat() {
    _sendBackspace();
    _stopBackspaceRepeat();

    // Initial typematic delay (400ms), followed by rapid repeat every 60ms
    _backspaceDelayTimer = Timer(const Duration(milliseconds: 400), () {
      _backspaceRepeatTimer = Timer.periodic(const Duration(milliseconds: 60), (
        _,
      ) {
        _sendBackspace();
      });
    });
  }

  void _stopBackspaceRepeat() {
    _backspaceDelayTimer?.cancel();
    _backspaceDelayTimer = null;
    _backspaceRepeatTimer?.cancel();
    _backspaceRepeatTimer = null;
  }

  @override
  void dispose() {
    _stopBackspaceRepeat();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: theme.colorScheme.surfaceContainer,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Keyboard toggle / focus button
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: IconButton.filledTonal(
              tooltip: l10n.openSoftwareKeyboard,
              icon: const Icon(Icons.keyboard, size: 22),
              onPressed: () {
                if (_focusNode.hasFocus) {
                  _focusNode.unfocus();
                } else {
                  _focusNode.requestFocus();
                }
              },
            ),
          ),
          const SizedBox(width: 8),

          // Input TextField
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              minLines: 1,
              maxLines: 4,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendEnter(),
              scrollPhysics: const ClampingScrollPhysics(),
              decoration: InputDecoration(
                hintText: l10n.typeToSend,
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withAlpha(120),
                ),
                isDense: true,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        tooltip: l10n.clearText,
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: _clearControllerSilently,
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Backspace button with continuous auto-repeat when held (no tooltip)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Semantics(
              label: l10n.backspace,
              button: true,
              child: Material(
                color: Colors.transparent,
                shape: CircleBorder(
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                    width: 1.0,
                  ),
                ),
                child: InkResponse(
                  highlightShape: BoxShape.circle,
                  radius: 20,
                  onTap: () {},
                  onTapDown: (_) => _startBackspaceRepeat(),
                  onTapUp: (_) => _stopBackspaceRepeat(),
                  onTapCancel: _stopBackspaceRepeat,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: Icon(
                        Icons.backspace_outlined,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Enter button
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: IconButton.filled(
              tooltip: l10n.enter,
              icon: const Icon(Icons.keyboard_return, size: 20),
              onPressed: _sendEnter,
            ),
          ),
        ],
      ),
    );
  }
}
