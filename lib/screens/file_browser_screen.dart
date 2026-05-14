import 'package:flutter/material.dart';
import '../models/message.dart';
import '../services/api_service.dart';

class FileBrowserScreen extends StatefulWidget {
  final ApiService api;
  const FileBrowserScreen({super.key, required this.api});

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen> {
  String _currentPath = 'C:\\';
  final List<FileEntry> _entries = [];
  final List<String> _history = [];
  bool _loading = false;
  String? _error;
  String? _statusMsg;

  @override
  void initState() {
    super.initState();
    _loadPath(_currentPath);
  }

  Future<void> _loadPath(String path) async {
    setState(() { _loading = true; _error = null; _statusMsg = null; });
    final result = await widget.api.listFiles(path);
    if (result['success'] == true) {
      final entries = (result['entries'] as List)
          .map((e) => FileEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _entries.clear();
          _entries.addAll(entries);
          _currentPath = result['path'] as String? ?? path;
          _loading = false;
        });
      }
    } else {
      if (mounted) setState(() { _error = result['error'] as String? ?? '加载失败'; _loading = false; });
    }
  }

  void _enterDir(String path) {
    _history.add(_currentPath);
    _loadPath(path);
  }

  void _goBack() {
    if (_history.isNotEmpty) {
      final prev = _history.removeLast();
      _loadPath(prev);
    }
  }

  Future<void> _downloadFile(String path, String name) async {
    setState(() => _statusMsg = '正在下载 $name...');
    final savePath = await widget.api.downloadFile(path, name);
    if (savePath != null && mounted) {
      setState(() => _statusMsg = '✅ 已下载: $name');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ 已下载: $name'), backgroundColor: Colors.green),
      );
    } else if (mounted) {
      setState(() => _statusMsg = '❌ 下载失败');
    }
  }

  void _showUploadDialog() {
    final pathController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213e),
        title: const Text('上传文件', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('输入电脑上要上传的文件路径',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: pathController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'C:\\文件.txt',
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: const Color(0xFF1a1a2e),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final filePath = pathController.text.trim();
              if (filePath.isEmpty) return;
              setState(() => _statusMsg = '正在上传...');
              final ok = await widget.api.uploadFile(filePath, destDir: _currentPath);
              if (ok && mounted) {
                setState(() => _statusMsg = '✅ 上传成功');
                _loadPath(_currentPath);
              } else if (mounted) {
                setState(() => _statusMsg = '❌ 上传失败');
              }
            },
            child: const Text('上传', style: TextStyle(color: Color(0xFFe94560))),
          ),
        ],
      ),
    );
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
              if (_history.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _goBack,
                ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showPathEditDialog(),
                  child: Text(_currentPath,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70),
                onPressed: () => _loadPath(_currentPath),
              ),
            ],
          ),
        ),
        if (_statusMsg != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: _statusMsg!.startsWith('✅')
                ? Colors.green.withAlpha(30)
                : Colors.orange.withAlpha(30),
            child: Row(
              children: [
                Icon(
                  _statusMsg!.startsWith('✅') ? Icons.check_circle : Icons.info,
                  size: 16,
                  color: _statusMsg!.startsWith('✅') ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(_statusMsg!,
                    style: TextStyle(fontSize: 13,
                        color: _statusMsg!.startsWith('✅')
                            ? Colors.green[200] : Colors.orange[200]))),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => setState(() => _statusMsg = null),
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                        const SizedBox(height: 12),
                        Text('加载失败', style: TextStyle(color: Colors.red[300], fontSize: 16)),
                        Text(_error!, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                      ],
                    ))
                  : _entries.isEmpty
                      ? Center(child: Text('空目录', style: TextStyle(color: Colors.grey[500])))
                      : ListView.builder(
                          itemCount: _entries.length,
                          itemBuilder: (ctx, i) {
                            final e = _entries[i];
                            return ListTile(
                              leading: Icon(
                                e.isDir ? Icons.folder : Icons.insert_drive_file,
                                color: e.isDir ? Colors.amber[300] : Colors.blue[300],
                              ),
                              title: Text(e.name,
                                  style: const TextStyle(color: Colors.white, fontSize: 14)),
                              subtitle: e.isDir
                                  ? null
                                  : Text(e.formattedSize,
                                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              trailing: e.isDir
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.download,
                                          color: Colors.white54, size: 20),
                                      onPressed: () => _downloadFile(e.path, e.name),
                                    ),
                              onTap: e.isDir ? () => _enterDir(e.path) : null,
                            );
                          },
                        ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          color: const Color(0xFF16213e),
          child: Row(
            children: [
              Expanded(child: Text('${_entries.length} 个项目',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13))),
              ElevatedButton.icon(
                onPressed: _showUploadDialog,
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('上传文件'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0f3460),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showPathEditDialog() {
    final controller = TextEditingController(text: _currentPath);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213e),
        title: const Text('输入路径', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1a1a2e),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () { Navigator.pop(ctx); _loadPath(controller.text); },
            child: const Text('前往', style: TextStyle(color: Color(0xFFe94560))),
          ),
        ],
      ),
    );
  }
}