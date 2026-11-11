class HostDevice {
  final String hostname;
  final String ip;
  final int port;
  final String os;
  final String version;
  DateTime lastSeen;
  String? token;

  HostDevice({
    required this.hostname,
    required this.ip,
    required this.port,
    required this.os,
    required this.version,
    required this.lastSeen,
    this.token,
  });

  String get id => '$ip:$port';

  Map<String, dynamic> toJson() => {
        'hostname': hostname,
        'ip': ip,
        'port': port,
        'os': os,
        'version': version,
        'token': token,
      };

  factory HostDevice.fromJson(Map<String, dynamic> json) => HostDevice(
        hostname: json['hostname'] ?? 'Unknown',
        ip: json['ip'] ?? '127.0.0.1',
        port: json['port'] ?? 53842,
        os: json['os'] ?? 'linux',
        version: json['version'] ?? '0.1.0',
        lastSeen: DateTime.now(),
        token: json['token'],
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HostDevice && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
