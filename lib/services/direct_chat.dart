import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DirectAIChat {
  String? _apiKey;
  String _model = 'deepseek-chat';
  static const _keyStorage = 'direct_api_key';
  static const _modelStorage = 'direct_api_model';

  bool get hasKey => _apiKey != null && _apiKey!.isNotEmpty;

  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString(_keyStorage);
    _model = prefs.getString(_modelStorage) ?? 'deepseek-chat';
  }

  Future<void> saveKey(String key) async {
    _apiKey = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStorage, key);
  }

  Future<void> saveModel(String model) async {
    _model = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelStorage, model);
  }

  String get model => _model;

  Future<String> sendMessage(String message, {List<Map<String, String>>? history}) async {
    if (!hasKey) return '请先在设置中配置 API Key';

    try {
      final messages = <Map<String, String>>[];
      messages.add({'role': 'system', 'content': '你是一个有用的AI助手。'});
      if (history != null) messages.addAll(history);
      messages.add({'role': 'user', 'content': message});

      final resp = await http.post(
        Uri.parse('https://api.deepseek.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': messages,
          'stream': false,
        }),
      ).timeout(const Duration(seconds: 60));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return data['choices'][0]['message']['content'] as String? ?? '（无响应）';
      } else {
        final err = jsonDecode(resp.body);
        return '❌ API 错误: ${err['error']?['message'] ?? resp.statusCode}';
      }
    } catch (e) {
      return '❌ 请求失败: $e';
    }
  }
}