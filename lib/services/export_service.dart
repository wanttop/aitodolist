// export_service.dart
import 'dart:convert';
import 'dart:io';
import '../models/task.dart';

class ExportService {
  static Future<void> exportTasks(List<Task> tasks) async {
    final jsonStr = jsonEncode(tasks.map((e) => e.toJson()).toList());
    final file = File('tasks_export.json');
    await file.writeAsString(jsonStr);
    // 可扩展为 TXT 或云同步
  }
}