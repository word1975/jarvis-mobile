import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/message.dart';

class ApiService {
  String _baseUrl;
  String? _pin;
  bool _authenticated = false;

  ApiService({required String host, int port = 5001, String? pin})
      : _baseUrl = 'http://$host:$port',
        _pin = pin;

  String get baseUrl => _baseUrl;
  bool get isAuthenticated => _authenticated;
  String? get pin => _pin;

  void updateHost(String host, {int port = 5001}) {
    _baseUrl = 'http://$host:$port';
    _authenticated = false;
  }

  void setPin(String pin) {
    _pin = pin;
    _authenticated = false;
  }

  Future<bool> verifyPin() async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/api/auth/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'pin': _pin}),
      ).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        _authenticated = true;
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<String> fetchPin() async {
    try {
      final resp = await http
          .get(Uri.parse('$_baseUrl/api/auth/pin'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return data['pin'] as String? ?? '';
      }
    } catch (_) {}
    return '';
  }

  Future<bool> ping() async {
    try {
      final resp = await http
          .get(Uri.parse('$_baseUrl/api/ping'))
          .timeout(const Duration(seconds: 3));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> sendCommand(String command) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/api/command'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'command': command}),
      ).timeout(const Duration(seconds: 60));
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<SystemStatus?> fetchSystemStatus() async {
    try {
      final resp = await http
          .get(Uri.parse('$_baseUrl/api/system/status'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        return SystemStatus.fromJson(
            jsonDecode(resp.body) as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> listFiles(String path) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/api/files/list'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'path': path}),
      ).timeout(const Duration(seconds: 10));
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<String?> downloadFile(String path, String filename) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/api/files/download'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'path': path}),
      ).timeout(const Duration(seconds: 30));
      if (resp.statusCode == 200) {
        final dir = await getApplicationDocumentsDirectory();
        final savePath = '${dir.path}/$filename';
        final file = File(savePath);
        await file.writeAsBytes(resp.bodyBytes);
        return savePath;
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<bool> uploadFile(String filePath, {String? destDir}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/files/upload'),
      );
      request.files.add(
        await http.MultipartFile.fromPath('file', filePath),
      );
      if (destDir != null) {
        request.fields['dest'] = destDir;
      }
      final streamedResp = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final resp = await http.Response.fromStream(streamedResp);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return data['success'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> captureScreenshot() async {
    try {
      final resp = await http
          .get(Uri.parse('$_baseUrl/api/screenshot'))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data['image'] as String?;
      }
    } catch (_) {}
    return null;
  }
}