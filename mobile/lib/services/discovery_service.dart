import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/host_device.dart';

class DiscoveryService extends ChangeNotifier {
  static const int discoveryPort = 53842;
  static const String discoveryMagic = 'ONECONTROL_DISCOVERY';
  static const String beaconMagic = 'ONECONTROL_BEACON';

  final Map<String, HostDevice> _devices = {};
  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  bool _isScanning = false;

  List<HostDevice> get devices => _devices.values.toList()
    ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));

  bool get isScanning => _isScanning;

  Future<void> startDiscovery() async {
    if (_isScanning) return;
    _isScanning = true;
    notifyListeners();

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );
      _socket?.broadcastEnabled = true;

      _socket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket?.receive();
          if (datagram != null) {
            _handleDatagram(datagram);
          }
        }
      });

      // Send initial discovery packet and repeat every 2 seconds
      _sendDiscoveryProbe();
      _broadcastTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        _sendDiscoveryProbe();
        _cleanupStaleDevices();
      });
    } catch (e) {
      debugPrint('Error starting discovery: $e');
      _isScanning = false;
      notifyListeners();
    }
  }

  void _sendDiscoveryProbe() {
    if (_socket == null) return;
    final payload = utf8.encode(jsonEncode({'magic': discoveryMagic}));
    try {
      _socket?.send(
        payload,
        InternetAddress('255.255.255.255'),
        discoveryPort,
      );
    } catch (e) {
      debugPrint('Broadcast send error: $e');
    }
  }

  void _handleDatagram(Datagram datagram) {
    try {
      final msg = utf8.decode(datagram.data);
      final json = jsonDecode(msg);

      if (json is Map<String, dynamic> && json['magic'] == beaconMagic) {
        final hostname = json['hostname'] as String? ?? 'Host PC';
        final port = (json['port'] as num?)?.toInt() ?? discoveryPort;
        final os = json['os'] as String? ?? 'linux';
        final version = json['version'] as String? ?? '0.1.0';
        final ip = datagram.address.address;

        final device = HostDevice(
          hostname: hostname,
          ip: ip,
          port: port,
          os: os,
          version: version,
          lastSeen: DateTime.now(),
        );

        final key = device.id;
        final existing = _devices[key];
        if (existing != null) {
          existing.lastSeen = DateTime.now();
          device.token = existing.token;
        }
        _devices[key] = device;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error parsing discovery datagram: $e');
    }
  }

  void _cleanupStaleDevices() {
    final now = DateTime.now();
    final toRemove = <String>[];
    _devices.forEach((id, dev) {
      if (now.difference(dev.lastSeen).inSeconds > 15) {
        toRemove.add(id);
      }
    });

    if (toRemove.isNotEmpty) {
      for (final id in toRemove) {
        _devices.remove(id);
      }
      notifyListeners();
    }
  }

  void addManualDevice(String ip, int port, {String hostname = 'Manual Host'}) {
    final dev = HostDevice(
      hostname: hostname,
      ip: ip,
      port: port,
      os: 'linux',
      version: 'manual',
      lastSeen: DateTime.now(),
    );
    _devices[dev.id] = dev;
    notifyListeners();
  }

  void stopDiscovery() {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _socket?.close();
    _socket = null;
    _isScanning = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stopDiscovery();
    super.dispose();
  }
}
