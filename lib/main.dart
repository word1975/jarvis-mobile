import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'services/websocket_service.dart';
import 'services/direct_chat.dart';
import 'screens/chat_screen.dart';
import 'screens/file_browser_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const JarvisApp());
}

class JarvisApp extends StatelessWidget {
  const JarvisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jarvis',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1a1a2e),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFe94560),
          secondary: Color(0xFF0f3460),
        ),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (ctx) => const LoginScreen(),
        '/home': (ctx) {
          final api = ModalRoute.of(ctx)!.settings.arguments as ApiService;
          return HomeScreen(api: api);
        },
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  final ApiService api;
  const HomeScreen({super.key, required this.api});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final WebSocketService _ws;
  late final DirectAIChat _directChat;
  String _host = '';
  int _port = 5001;

  @override
  void initState() {
    super.initState();
    _ws = WebSocketService();
    _directChat = DirectAIChat();
    _directChat.loadSaved();
    final uri = Uri.parse(widget.api.baseUrl);
    _host = uri.host;
    _port = uri.port;
    _connectWs();
  }

  void _connectWs() {
    final pin = widget.api.pin ?? '';
    final wsPort = _port == 5001 ? 5002 : _port + 1;
    if (_host.startsWith('https://') || widget.api.baseUrl.startsWith('https://')) {
      _ws.connect(_host, _port == 443 ? 443 : wsPort, pin, useSsl: true);
    } else {
      _ws.connect(_host, wsPort, pin);
    }
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (ctx) => _SettingsDialog(
        api: widget.api,
        directChat: _directChat,
        onSaved: () => setState(() {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connected = _ws.isConnected;
    final labels = connected
        ? ['对话', '文件', '状态', 'AI']
        : ['对话', '文件', '状态', 'AI'];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213e),
        title: Row(
          children: [
            const Text('🤖 Jarvis',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (connected ? Colors.green : Colors.red).withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                connected ? '已连接' : (widget.api.pin != null ? '离线模式' : '未连接'),
                style: TextStyle(
                  fontSize: 11,
                  color: connected ? Colors.green[300] : Colors.red[300],
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ChatScreen(api: widget.api, ws: _ws),
          FileBrowserScreen(api: widget.api),
          DashboardScreen(api: widget.api),
          _DirectChatScreen(directChat: _directChat, ws: _ws, serverApi: widget.api),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: const Color(0xFF16213e),
        indicatorColor: const Color(0xFF0f3460),
        destinations: [
          NavigationDestination(
              icon: Icon(connected ? Icons.chat_bubble_outline : Icons.chat_outlined),
              label: labels[0],
              selectedIcon: const Icon(Icons.chat_bubble, color: Color(0xFFe94560))),
          NavigationDestination(
              icon: const Icon(Icons.folder_outlined), label: labels[1],
              selectedIcon: const Icon(Icons.folder, color: Color(0xFFe94560))),
          NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined), label: labels[2],
              selectedIcon: const Icon(Icons.dashboard, color: Color(0xFFe94560))),
          NavigationDestination(
              icon: Icon(_directChat.hasKey ? Icons.auto_awesome_outlined : Icons.psychology_outlined),
              label: 'AI',
              selectedIcon: const Icon(Icons.auto_awesome, color: Color(0xFFe94560))),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ws.dispose();
    super.dispose();
  }
}

class _DirectChatScreen extends StatefulWidget {
  final DirectAIChat directChat;
  final WebSocketService ws;
  final ApiService serverApi;

  const _DirectChatScreen({
    required this.directChat,
    required this.ws,
    required this.serverApi,
  });

  @override
  State<_DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<_DirectChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatEntry> _messages = [];
  bool _sending = false;
  bool _useDirectMode = false;

  @override
  void initState() {
    super.initState();
    _useDirectMode = !widget.ws.isConnected && widget.directChat.hasKey;
    if (_useDirectMode) {
      _messages.add(_ChatEntry('sys', '💡 独立模式：直接通过 AI API 对话，无需桌面端运行'));
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty || _sending) return;
    _inputController.clear();
    setState(() {
      _messages.add(_ChatEntry('user', text));
      _sending = true;
    });

    if (_useDirectMode) {
      final reply = await widget.directChat.sendMessage(text);
      if (mounted) {
        setState(() {
          _messages.add(_ChatEntry('ai', reply));
          _sending = false;
        });
        _scrollDown();
      }
    } else {
      widget.ws.sendMessage(text);
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted && _sending) setState(() => _sending = false);
      });
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          color: const Color(0xFF16213e),
          child: Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _useDirectMode ? Colors.orange : (widget.ws.isConnected ? Colors.green : Colors.red),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _useDirectMode ? '独立模式' : (widget.ws.isConnected ? '已连接' : '未连接'),
                style: TextStyle(
                  fontSize: 12,
                  color: _useDirectMode
                      ? Colors.orange[300]
                      : (widget.ws.isConnected ? Colors.green[300] : Colors.red[300]),
                ),
              ),
              const Spacer(),
              if (widget.directChat.hasKey)
                GestureDetector(
                  onTap: () => setState(() => _useDirectMode = !_useDirectMode),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _useDirectMode ? Colors.orange.withAlpha(40) : Colors.white12,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _useDirectMode ? '切换服务器' : '切换AI直连',
                      style: TextStyle(fontSize: 11, color: _useDirectMode ? Colors.orange[300] : Colors.grey[400]),
                    ),
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
                      Icon(Icons.auto_awesome_outlined, size: 64, color: Colors.grey[700]),
                      const SizedBox(height: 16),
                      Text('AI 对话', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(
                        _useDirectMode ? '通过 API 直连，无需桌面端' : '通过服务器转发',
                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (ctx, i) => _buildBubble(_messages[i]),
                ),
        ),
        if (_sending)
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
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
                    hintText: '向 AI 提问...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: const Color(0xFF1a1a2e),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  onSubmitted: _sendMessage,
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFe94560),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: _sending ? null : () => _sendMessage(_inputController.text.trim()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBubble(_ChatEntry msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: msg.isUser ? const Color(0xFF0f3460) : const Color(0xFF16213e),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: msg.isUser ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: msg.isUser ? const Radius.circular(4) : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  msg.isUser ? '🧑 你' : '🤖 AI',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _ChatEntry {
  final String role;
  final String text;
  _ChatEntry(this.role, this.text);
  bool get isUser => role == 'user';
}

class _SettingsDialog extends StatefulWidget {
  final ApiService api;
  final DirectAIChat directChat;
  final VoidCallback onSaved;

  const _SettingsDialog({
    required this.api,
    required this.directChat,
    required this.onSaved,
  });

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late TextEditingController _keyController;
  late TextEditingController _modelController;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: '');
    _modelController = TextEditingController(text: widget.directChat.model);
  }

  Future<void> _saveKey() async {
    final key = _keyController.text.trim();
    if (key.isNotEmpty) {
      await widget.directChat.saveKey(key);
    }
    final model = _modelController.text.trim();
    if (model.isNotEmpty) {
      await widget.directChat.saveModel(model);
    }
    widget.onSaved();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 设置已保存'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF16213e),
      title: const Text('设置', style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('服务器', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1a1a2e),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(widget.api.baseUrl, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ),
            const SizedBox(height: 16),
            const Text('AI 直连 API Key（可选）', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _keyController,
              obscureText: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: widget.directChat.hasKey ? '已设置（输入新Key覆盖）' : 'sk-...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: const Color(0xFF1a1a2e),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            const Text('模型名称（可选）', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _modelController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'deepseek-chat',
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: const Color(0xFF1a1a2e),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
            if (widget.directChat.hasKey)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('✅ API Key 已配置', style: TextStyle(color: Colors.green[300], fontSize: 12)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: _saveKey,
          child: const Text('保存', style: TextStyle(color: Color(0xFFe94560))),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _keyController.dispose();
    _modelController.dispose();
    super.dispose();
  }
}