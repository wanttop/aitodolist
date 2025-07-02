import 'package:flutter/material.dart';
import '../models/task.dart';

class EditTaskPage extends StatefulWidget {
  final Task task;
  const EditTaskPage({super.key, required this.task});

  @override
  State<EditTaskPage> createState() => _EditTaskPageState();
}

class _EditTaskPageState extends State<EditTaskPage> {
  late TextEditingController _titleController;
  late bool _isDone;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _isDone = widget.task.isDone;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('编辑任务')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '任务标题'),
            ),
            CheckboxListTile(
              value: _isDone,
              onChanged: (v) => setState(() => _isDone = v!),
              title: const Text('已完成'),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                final edited = widget.task.copyWith(
                  title: _titleController.text,
                  isDone: _isDone,
                );
                Navigator.pop(context, edited);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
