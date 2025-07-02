import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/task_cloud_service.dart';

class TaskTile extends StatelessWidget {
  final Task task;

  const TaskTile({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        task.title,
        style: TextStyle(
          decoration: task.isDone ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: task.description != null ? Text(task.description!) : null,
      trailing: Checkbox(
        value: task.isDone,
        onChanged: (value) {
          if (value != null) {
            TaskCloudService.toggleDone(task.id, value);
          }
        },
      ),
    );
  }
}
