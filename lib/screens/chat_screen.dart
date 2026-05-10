import 'dart:async';
import 'package:flutter/material.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

class ChatScreen extends StatefulWidget {
  final ApiService api;
  final WebSocketService ws;

  const ChatScreen({super.key, required this.api, required this.ws});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  StreamSubscription<ChatMessage>? _msgSub;
  StreamSubscription<bool>? _connSub;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _msgSub = widget.ws.messages.listen(_onMessage);
    _connSub = widget.ws.connectionState.listen((connected) {
      if (mounted) setState(() {});
    });
  }

  void _onMessage(ChatMessage msg) {
    if (mounted) {
      setState(() => _messages.add(msg));
      _scrollDown();
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;
    _inputController.clear();
    setState(() => _sending = true);
    widget.ws.sendMessage(text);

    widget.api.sendCommand(text).then((_) {
      if (mounted) setState(() => _sending = false);
    }).catchError((_) {
      if (mounted) setState(() => _sending = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: const Color(0xFF16213e),
          child: Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.ws.isConnected ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.ws.isConnected ? '已连接' : '未连接',
                style: TextStyle(
                  color: widget.ws.isConnected
                      ? Colors.green[300]
                      : Colors.red[300],
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 64, color: Colors.grey[700]),
                      const SizedBox(height: 16),
                      Text('开始与 Jarvis 对话',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (ctx, i) => _buildMessageBubble(_messages[i]),
                ),
        ),
        if (_sending)
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          color: const Color(0xFF16213e),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: '输入命令...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: const Color(0xFF1a1a2e),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFe94560),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: _sending ? null : _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    final isSys = msg.isSystem;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSys
              ? const Color(0xFF1a1a2e)
              : isUser
                  ? const Color(0xFF0f3460)
                  : const Color(0xFF16213e),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser
                ? const Radius.circular(16)
                : const Radius.circular(4),
            bottomRight: isUser
                ? const Radius.circular(4)
                : const Radius.circular(16),
          ),
          border: isSys ? Border.all(color: Colors.white12) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isUser ? '🧑 你' : (isSys ? '⚙️ 系统' : '🤖 Jarvis'),
                  style: TextStyle(
                    fontSize: 11,
                    color: isSys
                        ? const Color(0xFFe94560)
                        : Colors.grey[500],
                  ),
                ),
                if (msg.displayTime.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    msg.displayTime,
                    style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              msg.text,
              style: TextStyle(
                color: isSys ? const Color(0xFFe94560) : Colors.white,
                fontSize: 14, height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _connSub?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}