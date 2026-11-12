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
  Timer? _recoveryTimer;
  Timer? _followUpTimer;
  bool _isScanning = false;
  bool _isPaused = false;
  DateTime? _lastResumeTime;

  List<HostDevice> get devices =>
      _devices.values.toList()
        ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));

  bool get isScanning => _isScanning && !_isPaused;

  Future<void> startDiscovery() async {
    if (_isScanning && !_isPaused) return;
    _isScanning = true;
    _isPaused = false;
    _lastResumeTime = DateTime.now();
    notifyListeners();

    try {
      _recoveryTimer?.cancel();
      _recoveryTimer = null;
      _followUpTimer?.cancel();
      _followUpTimer = null;
      _broadcastTimer?.cancel();
      _socket?.close();

      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );
      _socket?.broadcastEnabled = true;

      _socket?.listen(
        (RawSocketEvent event) {
          if (event == RawSocketEvent.read) {
            final datagram = _socket?.receive();
            if (datagram != null) {
              _handleDatagram(datagram);
            }
          }
        },
        onError: (Object error) {
          debugPrint('Discovery socket error: $error');
          _scheduleRecovery();
        },
        onDone: () {
          debugPrint('Discovery socket closed');
          _scheduleRecovery();
        },
      );

      // Send initial discovery packet immediately
      _sendDiscoveryProbe();

      // Follow up with an extra probe after 800ms to catch Wi-Fi interface wakeups
      _followUpTimer?.cancel();
      _followUpTimer = Timer(const Duration(milliseconds: 800), () {
        if (_isScanning && !_isPaused) {
          _sendDiscoveryProbe();
        }
      });

      // Repeat discovery packet and check for stale devices every 2 seconds
      _broadcastTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        _sendDiscoveryProbe();
        _cleanupStaleDevices();
      });
    } catch (e) {
      debugPrint('Error starting discovery: $e');
      _isScanning = false;
      notifyListeners();
      _scheduleRecovery();
    }
  }

  void _sendDiscoveryProbe() {
    final socket = _socket;
    if (socket == null) return;
    final payload = utf8.encode(jsonEncode({'magic': discoveryMagic}));

    // Broadcast probe to general broadcast address (255.255.255.255)
    try {
      final sent = socket.send(
        payload,
        InternetAddress('255.255.255.255'),
        discoveryPort,
      );
      if (sent == 0) {
        debugPrint('General broadcast probe returned 0 bytes');
      }
    } catch (e) {
      debugPrint('General broadcast send error: $e');
      _scheduleRecovery();
    }

    // Also send directed broadcast probes to local subnet broadcasts (e.g. 192.168.1.255)
    _sendSubnetProbes(socket, payload);
  }

  Future<void> _sendSubnetProbes(
    RawDatagramSocket socket,
    List<int> payload,
  ) async {
    try {
      final targets = await _getBroadcastAddresses();
      if (_socket != socket) return;

      for (final target in targets) {
        if (target.address == '255.255.255.255') continue;
        try {
          socket.send(payload, target, discoveryPort);
        } catch (e) {
          debugPrint('Subnet broadcast send error to ${target.address}: $e');
        }
      }
    } catch (e) {
      debugPrint('Error sending subnet probes: $e');
    }
  }

  Future<List<InternetAddress>> _getBroadcastAddresses() async {
    final ips = <String>{};
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              ips.add('${parts[0]}.${parts[1]}.${parts[2]}.255');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting broadcast addresses: $e');
    }

    final result = <InternetAddress>[];
    for (final ip in ips) {
      try {
        result.add(InternetAddress(ip));
      } catch (_) {}
    }
    return result;
  }

  void _scheduleRecovery() {
    if (_isPaused) return;
    _recoveryTimer?.cancel();
    _recoveryTimer = Timer(const Duration(seconds: 1), () {
      if (!_isPaused) {
        restartDiscovery();
      }
    });
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

    // Grace period after starting or resuming: give devices time to respond
    // before cleaning them up.
    if (_lastResumeTime != null &&
        now.difference(_lastResumeTime!).inSeconds < 6) {
      return;
    }

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

  /// Pauses discovery when the app is backgrounded or screen locked.
  /// Keeps known devices in memory to prevent showing an empty list on resume.
  void pauseDiscovery() {
    if (!_isScanning || _isPaused) return;
    _isPaused = true;
    _recoveryTimer?.cancel();
    _recoveryTimer = null;
    _followUpTimer?.cancel();
    _followUpTimer = null;
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _socket?.close();
    _socket = null;
    notifyListeners();
  }

  /// Resumes discovery when the app returns to foreground.
  Future<void> resumeDiscovery() async {
    _isPaused = false;
    _isScanning = false;
    await startDiscovery();
  }

  /// Restarts discovery immediately with a fresh socket (e.g. on manual refresh).
  Future<void> restartDiscovery({bool clearDevices = false}) async {
    if (clearDevices) {
      _devices.clear();
      notifyListeners();
    }
    stopDiscovery();
    await startDiscovery();
  }

  void stopDiscovery() {
    _recoveryTimer?.cancel();
    _recoveryTimer = null;
    _followUpTimer?.cancel();
    _followUpTimer = null;
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _socket?.close();
    _socket = null;
    _isScanning = false;
    _isPaused = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stopDiscovery();
    super.dispose();
  }
}
