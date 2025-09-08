import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const AarvoApp());
}

class AarvoApp extends StatelessWidget {
  const AarvoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppModel>(
      create: (_) => AppModel()..init(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Aarvo - All in One',
        theme: ThemeData(
          primarySwatch: Colors.indigo,
          useMaterial3: true,
        ),
        home: const HomePage(),
      ),
    );
  }
}

class AppModel extends ChangeNotifier {
  String uniqueCode = '';
  final List<String> messages = [];
  final List<PickedFileItem> files = [];
  final AudioPlayer audioPlayer = AudioPlayer();
  String searchQuery = '';
  int searchIndex = -1;

  Future<void> init() async {
    await _loadUniqueCode();
    await _loadSavedFiles();
    await _loadMessages();
  }

  Future<void> _loadUniqueCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('aarvo_unique_code');
    if (code == null) {
      final u = const Uuid().v4();
      uniqueCode = u.substring(0, 8).toUpperCase();
      await prefs.setString('aarvo_unique_code', uniqueCode);
    } else {
      uniqueCode = code;
    }
    notifyListeners();
  }

  Future<void> resetUniqueCode() async {
    final prefs = await SharedPreferences.getInstance();
    final u = const Uuid().v4();
    uniqueCode = u.substring(0, 8).toUpperCase();
    await prefs.setString('aarvo_unique_code', uniqueCode);
    notifyListeners();
  }

  Future<void> _loadSavedFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('aarvo_files') ?? [];
    files.clear();
    for (final s in saved) {
      files.add(PickedFileItem(path: s, name: s.split(Platform.pathSeparator).last));
    }
    notifyListeners();
  }

  Future<void> saveFilesToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('aarvo_files', files.map((e) => e.path).toList());
  }

  Future<void> addFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result == null) return;
      for (final f in result.files) {
        final path = f.path;
        if (path != null) {
          files.add(PickedFileItem(path: path, name: f.name));
        }
      }
      await saveFilesToPrefs();
      notifyListeners();
    } catch (e) {
      debugPrint('pick error: $e');
    }
  }

  Future<void> removeFileAt(int idx) async {
    if (idx < 0 || idx >= files.length) return;
    final removed = files.removeAt(idx);
    await saveFilesToPrefs();
    notifyListeners();
    debugPrint('removed ${removed.path}');
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('aarvo_messages') ?? [];
    messages.clear();
    messages.addAll(saved);
    notifyListeners();
  }

  Future<void> addMessage(String text) async {
    messages.add(text);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('aarvo_messages', messages);
    notifyListeners();
  }

  Future<void> clearMessages() async {
    messages.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('aarvo_messages', messages);
    notifyListeners();
  }

  // Search helpers
  void setSearch(String q) {
    searchQuery = q;
    searchIndex = -1;
    notifyListeners();
  }

  void findNext() {
    if (searchQuery.isEmpty) return;
    final list = [...messages, ...files.map((f) => f.name)];
    final start = searchIndex + 1;
    final n = list.length;
    for (int i = 0; i < n; i++) {
      final idx = (start + i) % n;
      if (list[idx].toLowerCase().contains(searchQuery.toLowerCase())) {
        searchIndex = idx;
        notifyListeners();
        return;
      }
    }
  }

  void findPrev() {
    if (searchQuery.isEmpty) return;
    final list = [...messages, ...files.map((f) => f.name)];
    final n = list.length;
    int start = searchIndex - 1;
    if (start < 0) start = n - 1;
    for (int i = 0; i < n; i++) {
      final idx = (start - i) % n;
      if (idx < 0) continue;
      if (list[idx].toLowerCase().contains(searchQuery.toLowerCase())) {
        searchIndex = idx;
        notifyListeners();
        return;
      }
    }
  }

  Future<void> playFileAt(int idx) async {
    if (idx < 0 || idx >= files.length) return;
    final path = files[idx].path;
    try {
      await audioPlayer.setFilePath(path);
      audioPlayer.play();
    } catch (e) {
      debugPrint('play error: $e');
    }
  }

  Future<void> stopAudio() async {
    await audioPlayer.stop();
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }
}

class PickedFileItem {
  final String path;
  final String name;
  PickedFileItem({required this.path, required this.name});
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _sel = 0;
  final TextEditingController _searchC = TextEditingController();
  final TextEditingController _msgC = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<AppModel>(context);

    Widget body;
    switch (_sel) {
      case 0:
        body = buildMain(model);
        break;
      case 1:
        body = buildMusic(model);
        break;
      case 2:
        body = buildFiles(model);
        break;
      case 3:
        body = buildMessages(model);
        break;
      case 4:
        body = buildSettings(model);
        break;
      default:
        body = buildMain(model);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aarvo'),
        centerTitle: true,
      ),
      body: body,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildSearchBar(model),
          BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _sel,
            onTap: (i) => setState(() => _sel = i),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.music_note), label: 'Music'),
              BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Files'),
              BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messages'),
              BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
            ],
          ),
        ],
      ),
      floatingActionButton: _sel == 3
          ? FloatingActionButton(
              onPressed: () => openAddMessageDialog(context, model),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget buildSearchBar(AppModel model) {
    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchC,
              decoration: const InputDecoration(
                hintText: 'Search messages, files, etc.',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.all(10),
              ),
              onChanged: (v) => model.setSearch(v),
            ),
          ),
          IconButton(
            tooltip: 'Prev',
            onPressed: () {
              model.findPrev();
              focusSearchToResult(model);
            },
            icon: const Icon(Icons.arrow_back_ios),
          ),
          IconButton(
            tooltip: 'Next',
            onPressed: () {
              model.findNext();
              focusSearchToResult(model);
            },
            icon: const Icon(Icons.arrow_forward_ios),
          ),
        ],
      ),
    );
  }

  void focusSearchToResult(AppModel model) {
    // Optionally highlight or scroll — basic demo: show Snack
    final q = model.searchQuery;
    final idx = model.searchIndex;
    if (q.isEmpty) return;
    final total = model.messages.length + model.files.length;
    final msg = idx >= 0 ? 'Found match at item ${idx + 1} / $total' : 'No result';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(milliseconds: 800)));
  }

  Widget buildMain(AppModel model) {
    return Padding(
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Unique Code:', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              SelectableText(model.uniqueCode, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: model.resetUniqueCode,
                child: const Text('Regenerate'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Suggestions:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: const Text('Play Music'), onDeleted: null),
              Chip(label: const Text('Open Files')),
              Chip(label: const Text('Send Message')),
              Chip(label: const Text('Enable Offline Mode')),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Quick Actions', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton.icon(onPressed: () => setState(() => _sel = 1), icon: const Icon(Icons.music_note), label: const Text('Music')),
              const SizedBox(width: 8),
              ElevatedButton.icon(onPressed: () => setState(() => _sel = 2), icon: const Icon(Icons.folder), label: const Text('Files')),
              const SizedBox(width: 8),
              ElevatedButton.icon(onPressed: () => setState(() => _sel = 3), icon: const Icon(Icons.message), label: const Text('Messages')),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildMusic(AppModel model) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          Row(
            children: [
              ElevatedButton.icon(onPressed: model.addFiles, icon: const Icon(Icons.add), label: const Text('Add Files')),
              const SizedBox(width: 8),
              ElevatedButton.icon(onPressed: model.stopAudio, icon: const Icon(Icons.stop), label: const Text('Stop')),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: model.files.isEmpty
                ? const Center(child: Text('No files. Add files to play audio.'))
                : ListView.builder(
                    itemCount: model.files.length,
                    itemBuilder: (context, idx) {
                      final f = model.files[idx];
                      return ListTile(
                        leading: const Icon(Icons.audiotrack),
                        title: Text(f.name),
                        subtitle: Text(f.path),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(onPressed: () => model.playFileAt(idx), icon: const Icon(Icons.play_arrow)),
                          IconButton(onPressed: () => model.removeFileAt(idx), icon: const Icon(Icons.delete)),
                        ]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget buildFiles(AppModel model) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          ElevatedButton.icon(onPressed: model.addFiles, icon: const Icon(Icons.upload_file), label: const Text('Add files')),
          const SizedBox(height: 12),
          Expanded(
            child: model.files.isEmpty
                ? const Center(child: Text('No files added'))
                : ListView.builder(
                    itemCount: model.files.length,
                    itemBuilder: (context, idx) {
                      final file = model.files[idx];
                      return ListTile(
                        leading: const Icon(Icons.insert_drive_file),
                        title: Text(file.name),
                        subtitle: Text(file.path),
                        trailing: IconButton(
                          onPressed: () => model.removeFileAt(idx),
                          icon: const Icon(Icons.delete),
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }

  Widget buildMessages(AppModel model) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _msgC,
                decoration: const InputDecoration(hintText: 'Type message to save locally'),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: () {
              final t = _msgC.text.trim();
              if (t.isEmpty) return;
              model.addMessage(t);
              _msgC.clear();
            }, child: const Text('Send')),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: model.messages.isEmpty
                ? const Center(child: Text('No local messages yet'))
                : ListView.builder(
                    itemCount: model.messages.length,
                    itemBuilder: (context, idx) {
                      final m = model.messages[idx];
                      return ListTile(
                        leading: const Icon(Icons.message),
                        title: Text(m),
                      );
                    },
                  ),
          ),
          ElevatedButton(onPressed: model.clearMessages, child: const Text('Clear messages')),
        ],
      ),
    );
  }

  Widget buildSettings(AppModel model) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Unique Code: ${model.uniqueCode}', style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        ElevatedButton(onPressed: model.resetUniqueCode, child: const Text('Regenerate Unique Code')),
        const SizedBox(height: 12),
        const Text('Notes:', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text(
          '- This is a starter app. Offline messaging is local only.\n'
          '- For real P2P calls/messages you must integrate platform APIs or a P2P transport.\n'
          '- For background downloads/advanced tasks add platform-specific setup.',
        ),
      ]),
    );
  }

  void openAddMessageDialog(BuildContext context, AppModel model) {
    showDialog(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Add Message'),
          content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Message')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(onPressed: () {
              final t = ctrl.text.trim();
              if (t.isNotEmpty) {
                model.addMessage(t);
                Navigator.pop(ctx);
              }
            }, child: const Text('Add')),
          ],
        );
      },
    );
  }
}
