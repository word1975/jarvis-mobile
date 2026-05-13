import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'services/websocket_service.dart';
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
      title: 'Jarvis 远程控制',
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
  String _host = '';
  int _port = 5001;

  @override
  void initState() {
    super.initState();
    _ws = WebSocketService();
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

  @override
  Widget build(BuildContext context) {
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
                color: (_ws.isConnected ? Colors.green : Colors.red).withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _ws.isConnected ? '已连接' : '未连接',
                style: TextStyle(
                  fontSize: 11,
                  color: _ws.isConnected ? Colors.green[300] : Colors.red[300],
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ChatScreen(api: widget.api, ws: _ws),
          FileBrowserScreen(api: widget.api),
          DashboardScreen(api: widget.api),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: const Color(0xFF16213e),
        indicatorColor: const Color(0xFF0f3460),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline), label: '对话',
              selectedIcon: Icon(Icons.chat_bubble, color: Color(0xFFe94560))),
          NavigationDestination(
              icon: Icon(Icons.folder_outlined), label: '文件',
              selectedIcon: Icon(Icons.folder, color: Color(0xFFe94560))),
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined), label: '状态',
              selectedIcon: Icon(Icons.dashboard, color: Color(0xFFe94560))),
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