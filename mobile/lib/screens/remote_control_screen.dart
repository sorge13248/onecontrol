import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/connection_service.dart';
import '../widgets/keyboard_bar_widget.dart';
import '../widgets/special_keys_widget.dart';
import '../widgets/trackpad_widget.dart';

class RemoteControlScreen extends StatefulWidget {
  final ConnectionService connectionService;

  const RemoteControlScreen({super.key, required this.connectionService});

  @override
  State<RemoteControlScreen> createState() => _RemoteControlScreenState();
}

class _RemoteControlScreenState extends State<RemoteControlScreen> {
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    widget.connectionService.addListener(_onStateChange);
  }

  @override
  void dispose() {
    widget.connectionService.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() {
    if (_isExiting) return;
    if (!widget.connectionService.isConnected && mounted) {
      _isExiting = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.connectionService.statusMessage),
          backgroundColor: Colors.redAccent,
        ),
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  void _handleExit() {
    if (_isExiting) return;
    _isExiting = true;
    widget.connectionService.disconnect();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final device = widget.connectionService.activeDevice;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && !_isExiting) {
          _isExiting = true;
          widget.connectionService.disconnect();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleExit,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                device?.hostname ?? l10n.remoteControl,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${device?.ip ?? ''} • ${l10n.connected}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withAlpha(160),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: l10n.disconnect,
              icon: const Icon(
                Icons.power_settings_new,
                color: Colors.redAccent,
              ),
              onPressed: _handleExit,
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Trackpad surface takes all available upper space
              Expanded(
                child: TrackpadWidget(
                  connectionService: widget.connectionService,
                ),
              ),

              // Modifiers & special keys (CTRL, SUPER, FN, ALT, SHIFT, TAB, STAMP)
              SpecialKeysWidget(connectionService: widget.connectionService),

              // Keyboard input field and soft keyboard controls
              KeyboardBarWidget(connectionService: widget.connectionService),
            ],
          ),
        ),
      ),
    );
  }
}
