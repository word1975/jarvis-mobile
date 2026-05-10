class ChatMessage {
  final String sender;
  final String text;
  final double time;

  ChatMessage({
    required this.sender,
    required this.text,
    required this.time,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      sender: json['sender'] as String? ?? 'sys',
      text: json['text'] as String? ?? '',
      time: (json['time'] as num?)?.toDouble() ?? 0,
    );
  }

  bool get isUser => sender == 'user';
  bool get isAi => sender == 'ai';
  bool get isSystem => sender == 'sys';

  String get displayTime {
    if (time == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch((time * 1000).toInt());
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class FileEntry {
  final String name;
  final String path;
  final bool isDir;
  final int size;
  final double modified;

  FileEntry({
    required this.name,
    required this.path,
    required this.isDir,
    required this.size,
    required this.modified,
  });

  factory FileEntry.fromJson(Map<String, dynamic> json) {
    return FileEntry(
      name: json['name'] as String? ?? '',
      path: json['path'] as String? ?? '',
      isDir: json['is_dir'] as bool? ?? false,
      size: json['size'] as int? ?? 0,
      modified: (json['modified'] as num?)?.toDouble() ?? 0,
    );
  }

  String get formattedSize {
    if (isDir) return '';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class SystemStatus {
  final double cpuPercent;
  final double memoryPercent;
  final double memoryUsed;
  final double memoryTotal;
  final Map<String, DiskInfo> disks;
  final String hostname;
  final String localIp;
  final double uptime;

  SystemStatus({
    required this.cpuPercent,
    required this.memoryPercent,
    required this.memoryUsed,
    required this.memoryTotal,
    required this.disks,
    required this.hostname,
    required this.localIp,
    required this.uptime,
  });

  factory SystemStatus.fromJson(Map<String, dynamic> json) {
    final mem = json['memory'] as Map<String, dynamic>? ?? {};
    final diskMap = <String, DiskInfo>{};
    if (json['disk'] is Map) {
      (json['disk'] as Map).forEach((key, val) {
        if (val is Map) {
          diskMap[key.toString()] = DiskInfo.fromJson(val.cast<String, dynamic>());
        }
      });
    }
    return SystemStatus(
      cpuPercent: (json['cpu_percent'] as num?)?.toDouble() ?? 0,
      memoryPercent: (mem['percent'] as num?)?.toDouble() ?? 0,
      memoryUsed: (mem['used'] as num?)?.toDouble() ?? 0,
      memoryTotal: (mem['total'] as num?)?.toDouble() ?? 0,
      disks: diskMap,
      hostname: json['hostname'] as String? ?? '',
      localIp: json['local_ip'] as String? ?? '',
      uptime: (json['uptime'] as num?)?.toDouble() ?? 0,
    );
  }

  String get uptimeFormatted {
    final days = (uptime / 86400).floor();
    final hours = ((uptime % 86400) / 3600).floor();
    return '${days}天${hours}小时';
  }
}

class DiskInfo {
  final double total;
  final double used;
  final double free;
  final double percent;
  final String mountpoint;

  DiskInfo({
    required this.total,
    required this.used,
    required this.free,
    required this.percent,
    required this.mountpoint,
  });

  factory DiskInfo.fromJson(Map<String, dynamic> json) {
    return DiskInfo(
      total: (json['total'] as num?)?.toDouble() ?? 0,
      used: (json['used'] as num?)?.toDouble() ?? 0,
      free: (json['free'] as num?)?.toDouble() ?? 0,
      percent: (json['percent'] as num?)?.toDouble() ?? 0,
      mountpoint: json['mountpoint'] as String? ?? '',
    );
  }

  String get formattedTotal => formatBytes(total);
  String get formattedUsed => formatBytes(used);
  String get formattedFree => formatBytes(free);

  static String formatBytes(double bytes) {
    if (bytes < 1024) return '${bytes.toStringAsFixed(0)} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes < 1024 * 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    return '${(bytes / (1024 * 1024 * 1024 * 1024)).toStringAsFixed(1)} TB';
  }
}