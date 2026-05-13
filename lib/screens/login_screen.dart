import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../models/message.dart';
import '../src/default_config.dart' show DefaultConfig;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _hostController = TextEditingController();
  final _pinController = TextEditingController();
  bool _connecting = false;
  String? _statusMsg;
  bool _showPinInput = false;
  String? _autoPin;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    _hostController.text = prefs.getString('jarvis_host') ?? DefaultConfig.host;
    if (DefaultConfig.hasPublicUrl && _hostController.text == DefaultConfig.host) {
      setState(() => _statusMsg = '🌐 检测到公网地址，可一键连接');
    }
  }

  Future<void> _saveHost() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jarvis_host', _hostController.text.trim());
  }

  Future<void> _tryConnect(String host) async {
    if (host.isEmpty) {
      setState(() => _statusMsg = host.isEmpty && DefaultConfig.host.isNotEmpty
          ? '正在使用默认地址 $DefaultConfig.host...'
          : '请输入IP地址');
      if (host.isEmpty && DefaultConfig.host.isNotEmpty) {
        host = DefaultConfig.host;
        _hostController.text = host;
      } else if (host.isEmpty) {
        return;
      }
    }
    setState(() {
      _connecting = true;
      _statusMsg = '正在连接 $host...';
    });

    if (_showPinInput && _pinController.text.isNotEmpty) {
      final api = ApiService(host: host, pin: _pinController.text.trim());
      final ok = await api.verifyPin();
      if (ok && mounted) {
        await _saveHost();
        Navigator.pushReplacementNamed(context, '/home', arguments: api);
        return;
      }
      if (mounted) setState(() => _statusMsg = '❌ PIN码错误，请重试');
      setState(() => _connecting = false);
      return;
    }

    final api = ApiService(host: host);
    final pin = await api.fetchPin();
    if (pin.isNotEmpty && mounted) {
      setState(() {
        _autoPin = pin;
        _pinController.text = pin;
        _showPinInput = true;
        _statusMsg = '🔑 请输入PIN码连接 (服务器PIN: $pin)';
        _connecting = false;
      });
    } else if (mounted) {
      setState(() {
        _statusMsg = '❌ 无法连接到服务器 $host:5001';
        _connecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🤖', style: TextStyle(fontSize: 72)),
                const SizedBox(height: 16),
                const Text('Jarvis 远程控制',
                    style: TextStyle(fontSize: 28,
                        fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                Text('连接您的电脑助手',
                    style: TextStyle(fontSize: 16, color: Colors.grey[400])),
                const SizedBox(height: 48),
                TextField(
                  controller: _hostController,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: '电脑IP地址',
                    hintText: '192.168.1.x',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF16213e),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.computer, color: Colors.grey),
                  ),
                ),
                if (_showPinInput) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pinController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'PIN码',
                      hintText: '输入6位数字PIN码',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF16213e),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon:
                          const Icon(Icons.lock_outline, color: Colors.grey),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (DefaultConfig.hasPublicUrl) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: _connecting
                          ? null
                          : () => _tryConnect(DefaultConfig.publicUrl),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4CAF50),
                        side: const BorderSide(color: Color(0xFF4CAF50)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.public, size: 18),
                      label: const Text('🌐 通过公网连接',
                          style: TextStyle(fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _connecting
                        ? null
                        : () => _tryConnect(_hostController.text.trim()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFe94560),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _connecting
                        ? const SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('连接', style: TextStyle(fontSize: 18)),
                  ),
                ),
                if (_statusMsg != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _statusMsg!,
                    style: TextStyle(
                      color: _statusMsg!.startsWith('✅')
                          ? Colors.green[300]
                          : Colors.orange[300],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hostController.dispose();
    _pinController.dispose();
    super.dispose();
  }
}