import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/message.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<ChatMessage> _messageController =
      StreamController<ChatMessage>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  bool _connected = false;
  String? _pin;
  Timer? _pingTimer;

  Stream<ChatMessage> get messages => _messageController.stream;
  Stream<bool> get connectionState => _connectionController.stream;
  bool get isConnected => _connected;

  void connect(String host, int port, String pin, {bool useSsl = false}) {
    _pin = pin;
    disconnect();

    try {
      final scheme = useSsl ? 'wss' : 'ws';
      final uri = Uri.parse('$scheme://$host:$port/ws');
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        (data) {
          if (data is String) {
            _handleMessage(data);
          }
        },
        onDone: () {
          _connected = false;
          _connectionController.add(false);
        },
        onError: (error) {
          _connected = false;
          _connectionController.add(false);
        },
      );

      _connected = true;
      _connectionController.add(true);

      _channel!.sink.add(jsonEncode({
        'type': 'auth',
        'pin': pin,
      }));

      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        try {
          _channel?.sink.add(jsonEncode({'type': 'ping'}));
        } catch (_) {}
      });
    } catch (e) {
      _connected = false;
      _connectionController.add(false);
    }
  }

  void _handleMessage(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final type = json['type'] as String? ?? 'chat';

      if (type == 'auth_ok') {
        return;
      } else if (type == 'auth_fail') {
        _connectionController.add(false);
        return;
      } else if (type == 'pong') {
        return;
      } else if (type == 'ack') {
        return;
      }

      final msg = ChatMessage(
        sender: json['sender'] as String? ?? 'sys',
        text: json['text'] as String? ?? '',
        time: (json['time'] as num?)?.toDouble() ?? 0,
      );
      _messageController.add(msg);
    } catch (_) {}
  }

  void sendMessage(String text) {
    if (_channel != null && _connected) {
      _channel!.sink.add(jsonEncode({
        'type': 'chat',
        'text': text,
      }));
      _messageController.add(ChatMessage(
        sender: 'user',
        text: text,
        time: DateTime.now().millisecondsSinceEpoch / 1000,
      ));
    }
  }

  void disconnect() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _channel?.sink.close();
    _channel = null;
    _connected = false;
    _connectionController.add(false);
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _connectionController.close();
  }
}