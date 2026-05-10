import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/message.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  final ApiService api;
  const DashboardScreen({super.key, required this.api});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  SystemStatus? _status;
  String? _screenshotB64;
  bool _loadingStatus = true;
  bool _loadingScreenshot = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  Future<void> _refresh() async {
    final status = await widget.api.fetchSystemStatus();
    if (mounted) setState(() { _status = status; _loadingStatus = false; });
  }

  Future<void> _captureScreenshot() async {
    setState(() => _loadingScreenshot = true);
    final b64 = await widget.api.captureScreenshot();
    if (mounted) setState(() { _screenshotB64 = b64; _loadingScreenshot = false; });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('电脑状态',
              style: TextStyle(fontSize: 20,
                  fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),

          if (_loadingStatus)
            const Center(child: CircularProgressIndicator())
          else if (_status == null)
            Center(child: Text('无法获取状态', style: TextStyle(color: Colors.grey[500])))
          else ...[
            _buildInfoCard('💻 主机', _status!.hostname, Icons.computer),
            _buildInfoCard('🌐 IP地址', _status!.localIp, Icons.wifi),
            _buildInfoCard('⏱ 运行', _status!.uptimeFormatted, Icons.timer),

            const SizedBox(height: 16),
            Text('CPU', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
            const SizedBox(height: 6),
            _buildProgressBar(_status!.cpuPercent, _cpuColor(_status!.cpuPercent)),

            const SizedBox(height: 16),
            Text('内存', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
            const SizedBox(height: 6),
            _buildProgressBar(_status!.memoryPercent, _memColor(_status!.memoryPercent)),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${DiskInfo.formatBytes(_status!.memoryUsed)} / ${DiskInfo.formatBytes(_status!.memoryTotal)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),

            const SizedBox(height: 16),
            Text('磁盘', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
            const SizedBox(height: 8),
            ..._status!.disks.entries.map((e) => _buildDiskCard(e.key, e.value)),

            const SizedBox(height: 16),
            Row(
              children: [
                Text('远程截屏', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _loadingScreenshot ? null : _captureScreenshot,
                  icon: _loadingScreenshot
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.camera_alt, size: 18),
                  label: Text(_loadingScreenshot ? '截取中...' : '截取屏幕'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0f3460),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
            if (_screenshotB64 != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  base64Decode(_screenshotB64!),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200, color: const Color(0xFF16213e),
                    child: const Center(child: Text('截图加载失败',
                        style: TextStyle(color: Colors.grey))),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16213e),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFe94560), size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double percent, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: percent / 100,
        backgroundColor: const Color(0xFF1a1a2e),
        valueColor: AlwaysStoppedAnimation(color),
        minHeight: 10,
      ),
    );
  }

  Widget _buildDiskCard(String device, DiskInfo disk) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213e),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.storage, color: Color(0xFFe94560), size: 18),
            const SizedBox(width: 8),
            Text(device,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${disk.percent.toStringAsFixed(1)}%',
                style: TextStyle(color: Colors.grey[400])),
          ]),
          const SizedBox(height: 8),
          _buildProgressBar(disk.percent, _diskColor(disk.percent)),
          const SizedBox(height: 4),
          Text('${disk.formattedUsed} / ${disk.formattedTotal}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }

  Color _cpuColor(double p) => p > 80 ? Colors.red : (p > 50 ? Colors.orange : Colors.green);
  Color _memColor(double p) => p > 80 ? Colors.red : (p > 60 ? Colors.orange : Colors.green);
  Color _diskColor(double p) => p > 90 ? Colors.red : (p > 70 ? Colors.orange : Colors.green);

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}