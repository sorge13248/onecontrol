import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/host_device.dart';
import '../services/connection_service.dart';
import '../services/discovery_service.dart';
import 'remote_control_screen.dart';

class DiscoveryScreen extends StatefulWidget {
  final DiscoveryService discoveryService;
  final ConnectionService connectionService;

  const DiscoveryScreen({
    super.key,
    required this.discoveryService,
    required this.connectionService,
  });

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  bool _isRemoteOpen = false;

  @override
  void initState() {
    super.initState();
    widget.discoveryService.startDiscovery();
    widget.connectionService.addListener(_onConnectionStateChanged);
  }

  @override
  void dispose() {
    widget.connectionService.removeListener(_onConnectionStateChanged);
    super.dispose();
  }

  void _onConnectionStateChanged() {
    final status = widget.connectionService.status;
    if (status == ConnectionStateStatus.pinRequired) {
      _showPinDialog();
    } else if (status == ConnectionStateStatus.connected) {
      // Navigate to Remote Control Screen
      if (mounted && !_isRemoteOpen) {
        _isRemoteOpen = true;
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (_) => RemoteControlScreen(
                  connectionService: widget.connectionService,
                ),
              ),
            )
            .then((_) {
              _isRemoteOpen = false;
            });
      }
    }
  }

  void _showPinDialog() {
    final l10n = AppLocalizations.of(context);
    final pinController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.lock_outline, color: Colors.blue),
            const SizedBox(width: 8),
            Text(l10n.pcPairing),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.pcPairingPrompt),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              autofocus: true,
              maxLength: 6,
              style: const TextStyle(
                fontSize: 24,
                letterSpacing: 8,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: '123456',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.connectionService.disconnect();
            },
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final pin = pinController.text.trim();
              if (pin.isNotEmpty) {
                Navigator.of(ctx).pop();
                widget.connectionService.submitPin(pin);
              }
            },
            child: Text(l10n.confirmPin),
          ),
        ],
      ),
    );
  }

  void _showManualConnectionDialog() {
    final l10n = AppLocalizations.of(context);
    final ipController = TextEditingController(text: '192.168.1.');
    final portController = TextEditingController(text: '53842');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.manualConnection),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ipController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.hostIpAddress,
                hintText: l10n.hostIpHint,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: portController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.port,
                hintText: '53842',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final ip = ipController.text.trim();
              final port = int.tryParse(portController.text.trim()) ?? 53842;
              if (ip.isNotEmpty) {
                Navigator.of(ctx).pop();
                final dev = HostDevice(
                  hostname: l10n.manualHost(ip),
                  ip: ip,
                  port: port,
                  os: 'linux',
                  version: 'manual',
                  lastSeen: DateTime.now(),
                );
                widget.connectionService.connect(dev);
              }
            },
            child: Text(l10n.connect),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.gamepad_outlined, color: Colors.blueAccent),
            const SizedBox(width: 8),
            Text(
              l10n.appTitle,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.addPcManually,
            icon: const Icon(Icons.add_link),
            onPressed: _showManualConnectionDialog,
          ),
          IconButton(
            tooltip: l10n.refreshScan,
            icon: const Icon(Icons.refresh),
            onPressed: () {
              widget.discoveryService.stopDiscovery();
              widget.discoveryService.startDiscovery();
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          widget.discoveryService,
          widget.connectionService,
        ]),
        builder: (context, _) {
          final devices = widget.discoveryService.devices;
          final status = widget.connectionService.status;
          final statusMsg = widget.connectionService.statusMessage;

          return Column(
            children: [
              // Connection status header bar if active
              if (status == ConnectionStateStatus.connecting ||
                  status == ConnectionStateStatus.handshaking ||
                  status == ConnectionStateStatus.error) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  color: status == ConnectionStateStatus.error
                      ? theme.colorScheme.errorContainer
                      : theme.colorScheme.primaryContainer,
                  child: Row(
                    children: [
                      if (status != ConnectionStateStatus.error)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          Icons.error_outline,
                          color: theme.colorScheme.error,
                          size: 20,
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          statusMsg,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: status == ConnectionStateStatus.error
                                ? theme.colorScheme.onErrorContainer
                                : theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Scanning indicator
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                child: Row(
                  children: [
                    const Icon(
                      Icons.wifi_tethering,
                      size: 16,
                      color: Colors.blueAccent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.searchingLan,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    if (widget.discoveryService.isScanning)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.8),
                      ),
                  ],
                ),
              ),

              // Device List
              Expanded(
                child: devices.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.computer_outlined,
                                size: 64,
                                color: theme.colorScheme.outline,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.noPcsFound,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.ensureDaemonRunning,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 20),
                              OutlinedButton.icon(
                                onPressed: _showManualConnectionDialog,
                                icon: const Icon(Icons.edit),
                                label: Text(l10n.enterIpManually),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          final device = devices[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                radius: 24,
                                backgroundColor:
                                    theme.colorScheme.primaryContainer,
                                child: Icon(
                                  device.os == 'linux'
                                      ? Icons.terminal
                                      : (device.os == 'windows'
                                            ? Icons.window
                                            : Icons.laptop_mac),
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              title: Text(
                                device.hostname,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${device.ip}:${device.port}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      device.os.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: FilledButton.tonal(
                                onPressed: () {
                                  widget.connectionService.connect(device);
                                },
                                child: Text(l10n.connect),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
