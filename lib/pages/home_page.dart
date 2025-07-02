import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../services/task_storage.dart';
import 'add_task_page.dart';
import '../theme/theme_provider.dart';
import 'calendar_page.dart';
import '../services/session_manager.dart';
import 'login_page.dart';
import 'user_profile_page.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Task> tasks = [];
  bool loading = true;
  String? selectedGroup;
  String? _username;
  late stt.SpeechToText _speech;
  String _lastWords = '';
  String? _aiReply;
  final TextEditingController _aiController = TextEditingController();
  List<Map<String, String>> _messages = [];
  bool _isListening = false;
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _loadTasks();
    _loadUsername();
    _loadMessages();
  }

  Future<void> _loadTasks() async {
    final username = await SessionManager.getUsername();
    if (username != null && username.isNotEmpty) {
      try {
        final cloudTasks = await getCloudTasks(username);
        final taskList = cloudTasks.map((e) => Task.fromJson(e)).toList();
        await TaskStorage.saveTasks(taskList);
        setState(() {
          tasks = taskList;
          loading = false;
        });
        return;
      } catch (e) {}
    }
    final loaded = await TaskStorage.loadTasks();
    setState(() {
      tasks = loaded;
      loading = false;
    });
  }

  Future<void> _loadUsername() async {
    final name = await SessionManager.getUsername();
    setState(() {
      _username = name;
    });
  }

  Future<void> _toggleDone(Task task) async {
    setState(() {
      task.isDone = !task.isDone;
    });
    await TaskStorage.saveTasks(tasks);
    await _autoSync();
  }

  Future<void> _deleteTask(Task task) async {
    setState(() {
      tasks.remove(task);
    });
    await TaskStorage.saveTasks(tasks);
    await _autoSync();
  }

  Future<void> _addNewTask() async {
    final newTask = await Navigator.push<Task>(
      context,
      MaterialPageRoute(builder: (context) => const AddTaskPage()),
    );
    if (newTask != null) {
      setState(() {
        tasks.add(newTask);
      });
      await TaskStorage.saveTasks(tasks);
      await _autoSync();
    }
  }

  Future<void> _autoSync() async {
    final username = await SessionManager.getUsername();
    if (username != null && username.isNotEmpty) {
      await syncTasks(username, tasks);
    }
  }

  Set<String> get allGroups {
    final groups = <String>{};
    for (var t in tasks) {
      if (t.tags.isNotEmpty) {
        groups.addAll(t.tags);
      }
    }
    return groups.isEmpty ? {'普通任务'} : groups;
  }

  List<Task> get filteredTasks {
    if (selectedGroup == null) return tasks;
    return tasks.where((t) => t.tags.contains(selectedGroup)).toList();
  }

  // 保存历史
  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('ai_messages', jsonEncode(_messages));
  }

  // 加载历史
  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('ai_messages');
    if (str != null) {
      setState(() {
        _messages = List<Map<String, String>>.from(jsonDecode(str));
      });
    }
  }

  Future<void> _sendAiMessage() async {
    final text = _aiController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _aiReply = null;
      _messages.add({'role': 'user', 'text': text});
    });
    _aiController.clear();
    await _saveMessages();

    // 只保留最近10条历史
    final history = _messages.length > 10
        ? _messages.sublist(_messages.length - 10)
        : _messages;

    // 全部任务序列化
    final allTasks = tasks
        .map((t) => {
              'title': t.title,
              'dueDate': t.dueDate?.toIso8601String(),
              'isDone': t.isDone,
              'tags': t.tags,
              'priority': t.priority,
              // 如有其它字段可继续加
            })
        .toList();

    final resp = await http.post(
      Uri.parse('http://127.0.0.1:9000/smart_parse'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'text': text,
        'history': history,
        'tasks': allTasks, // 传递全部任务
      }),
    );
    final data = jsonDecode(resp.body);
    final aiText = data['reply'] ?? 'AI无回复';
    setState(() {
      _aiReply = aiText;
      _messages.add({'role': 'ai', 'text': aiText});
    });
    await _saveMessages();
    await _tts.setLanguage("zh-CN");
    await _tts.speak(aiText);
  }

  Future<void> _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _aiController.text = result.recognizedWords;
          });
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 2),
        localeId: "zh_CN",
        cancelOnError: true,
        partialResults: true,
      );
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          selectedGroup == null
              ? (_username == null || _username!.isEmpty
                  ? '智能待办日历'
                  : '欢迎，$_username')
              : '分组：$selectedGroup',
        ),
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return IconButton(
                icon: Icon(
                  themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                ),
                onPressed: () {
                  themeProvider.toggleTheme();
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.cloud_sync),
            tooltip: '云同步',
            onPressed: () async {
              final username = await SessionManager.getUsername();
              if (username == null || username.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请先登录')),
                );
                return;
              }
              await syncTasks(username, tasks);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('同步到云端成功')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.cloud_download),
            tooltip: '从云端拉取',
            onPressed: () async {
              final username = await SessionManager.getUsername();
              if (username == null || username.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请先登录')),
                );
                return;
              }
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('警告'),
                  content: const Text('从云端拉取将覆盖本地所有任务，确定继续吗？'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('取消')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('确定')),
                  ],
                ),
              );
              if (confirm != true) return;
              final cloudTasks = await getCloudTasks(username);
              final taskList = cloudTasks.map((e) => Task.fromJson(e)).toList();
              await TaskStorage.saveTasks(taskList);
              setState(() {
                tasks = taskList;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已从云端拉取任务')),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            SafeArea(
              child: ListTile(
                leading: const Icon(
                  Icons.account_circle,
                  size: 32,
                  color: Colors.blue,
                ),
                title: FutureBuilder<String?>(
                  future: SessionManager.getUsername(),
                  builder: (context, snapshot) {
                    final username = snapshot.data;
                    return Text(
                      username == null || username.isEmpty ? '登录' : username,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
                onTap: () async {
                  final username = await SessionManager.getUsername();
                  if (username == null || username.isEmpty) {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                    if (result == true) {
                      _loadUsername();
                    }
                  }
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('日历'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CalendarPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('全部任务'),
              selected: selectedGroup == null,
              onTap: () {
                setState(() {
                  selectedGroup = null;
                });
                Navigator.pop(context);
              },
            ),
            ...allGroups.map(
              (group) => ListTile(
                leading: const Icon(Icons.folder),
                title: Text(group),
                selected: selectedGroup == group,
                onTap: () {
                  setState(() {
                    selectedGroup = group;
                  });
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('个人信息'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserProfilePage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.color_lens),
              title: const Text('切换主题'),
              onTap: () {
                Provider.of<ThemeProvider>(context, listen: false)
                    .toggleTheme();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('退出登录'),
              onTap: () async {
                await SessionManager.clearSession();
                setState(() {
                  _username = null;
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: filteredTasks.length,
                  itemBuilder: (context, index) {
                    final task = filteredTasks[index];
                    return ListTile(
                      title: Row(
                        children: [
                          if (task.priority == 1)
                            const Icon(
                              Icons.priority_high,
                              color: Colors.red,
                              size: 18,
                            ),
                          if (task.priority == 3)
                            const Icon(
                              Icons.low_priority,
                              color: Colors.green,
                              size: 18,
                            ),
                          const SizedBox(width: 4),
                          Text(
                            task.title,
                            style: TextStyle(
                              decoration: task.isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (task.dueDate != null)
                            Text(
                              '截止日期: ${task.dueDate!.toLocal().toString().split(' ')[0]}',
                            ),
                          if (task.tags.isNotEmpty)
                            Wrap(
                              spacing: 4,
                              children: task.tags
                                  .map(
                                    (tag) => Chip(
                                      label: Text(tag),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  )
                                  .toList(),
                            ),
                        ],
                      ),
                      leading: Checkbox(
                        value: task.isDone,
                        onChanged: (val) => _toggleDone(task),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteTask(task),
                      ),
                      onTap: () async {
                        final edited = await Navigator.push<Task>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => AddTaskPage(task: task)),
                        );
                        if (edited != null) {
                          setState(() {
                            final idx = tasks.indexOf(task);
                            tasks[idx] = edited;
                          });
                          await TaskStorage.saveTasks(tasks);
                          await _autoSync();
                        }
                      },
                    );
                  },
                ),
          // AI回复气泡
          if (_aiReply != null)
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 2 / 3,
                height: MediaQuery.of(context).size.height * 2 / 3,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85), // 半透明
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: SingleChildScrollView(
                        child: Center(
                          child: Text(
                            _aiReply!,
                            style: const TextStyle(
                                fontSize: 20, color: Colors.black87),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 28),
                        onPressed: () {
                          setState(() {
                            _aiReply = null;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // 底部AI对话输入区
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Container(
                color: Colors.transparent,
                padding: const EdgeInsets.fromLTRB(12, 4, 70, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(_isListening ? Icons.mic : Icons.mic_none,
                          color: Colors.teal),
                      onPressed:
                          _isListening ? _stopListening : _startListening,
                      tooltip: _isListening ? '停止语音输入' : '语音输入',
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _aiController,
                          minLines: 1,
                          maxLines: 4,
                          style: const TextStyle(fontSize: 16),
                          decoration: const InputDecoration(
                            hintText: '和AI对话...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          onSubmitted: (_) => _sendAiMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.teal,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: _sendAiMessage,
                        tooltip: '发送',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70),
        child: FloatingActionButton(
          onPressed: _addNewTask,
          child: const Icon(Icons.add),
          tooltip: '手动新建任务',
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
