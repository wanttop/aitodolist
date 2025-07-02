import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';

const String baseUrl = 'http://127.0.0.1:9000'; // ← 这里改成本地后端地址

class TaskStorage {
  static const _key = 'tasks';

  static Future<List<Task>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null) return [];
    final List<dynamic> list = jsonDecode(jsonString);
    return list.map((e) => Task.fromJson(e)).toList();
  }

  static Future<void> saveTasks(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(tasks.map((e) => e.toJson()).toList());
    await prefs.setString(_key, jsonString);
  }
}

Future<http.Response> register(String username, String password) async {
  return await http.post(
    Uri.parse('$baseUrl/register'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'username': username, 'password': password}),
  );
}

Future<http.Response> login(String username, String password) async {
  return await http.post(
    Uri.parse('$baseUrl/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'username': username, 'password': password}),
  );
}

Future<void> syncTasks(String username, List tasks) async {
  final response = await http.post(
    Uri.parse('$baseUrl/sync'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'username': username, 'tasks': tasks}),
  );
  print(response.body);
}

Future<List> getCloudTasks(String username) async {
  final response = await http.get(
    Uri.parse('$baseUrl/get_tasks?username=$username'),
  );
  final data = jsonDecode(response.body);
  if (data['code'] == 200) {
    return data['tasks'] ?? [];
  } else {
    throw Exception(data['msg'] ?? '获取云端任务失败');
  }
}
