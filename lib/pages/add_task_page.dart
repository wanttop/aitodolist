import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../services/notification_service.dart';

class AddTaskPage extends StatefulWidget {
  final Task? task; // 新增：可选参数
  const AddTaskPage({super.key, this.task});

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  String? _description;
  int _priority = 2;
  final List<String> _tags = [];
  DateTime? _dueDate; // 截止日期
  DateTime? _remindDateTime; // 提醒日期+时间
  String _repeat = '无';
  final List<String> _groups = ['普通任务', '工作', '学习', '生活', '其他'];
  String _group = '普通任务';

  final _tagController = TextEditingController();

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      // 编辑模式，初始化为已有任务
      _title = widget.task!.title;
      _description = widget.task!.description;
      _priority = widget.task!.priority;
      _tags.addAll(widget.task!.tags);
      _dueDate = widget.task!.dueDate;
      // 修正如下，避免 tags 为空时报错
      if (widget.task!.tags.isNotEmpty) {
        _group = widget.task!.tags.last;
      } else {
        _group = '普通任务'; // 或其它默认分组
      }
      // 其它字段同理
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  Future<void> _showAddGroupDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建分组'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '请输入分组名'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty && !_groups.contains(name)) {
                Navigator.pop(context, name);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (result != null && !_groups.contains(result)) {
      setState(() {
        _groups.add(result);
        _group = result;
      });
    }
  }

  void _quickSetReminder(String type) {
    DateTime now = DateTime.now();
    DateTime? date;
    if (type == '明日9:00') {
      date = DateTime(now.year, now.month, now.day + 1, 9, 0);
    } else if (type == '下周一9:00') {
      int daysToMonday = (8 - now.weekday) % 7;
      date = DateTime(now.year, now.month, now.day + daysToMonday, 9, 0);
    }
    if (date != null) {
      setState(() {
        _remindDateTime = date;
      });
    }
  }

  Future<void> _pickRemindDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _remindDateTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: 9, minute: 0),
      );
      if (pickedTime != null) {
        setState(() {
          _remindDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final task = widget.task == null
        ? Task(
            id: const Uuid().v4(),
            title: _title,
            description: _description,
            dueDate: _dueDate,
            priority: _priority,
            tags: [..._tags, _group],
          )
        : widget.task!.copyWith(
            title: _title,
            description: _description,
            dueDate: _dueDate,
            priority: _priority,
            tags: [..._tags, _group],
          );

    if (_remindDateTime != null) {
      await NotificationService.scheduleNotification(
        task.id.hashCode,
        '任务提醒',
        _title,
        _remindDateTime!,
      );
    }

    Navigator.pop(context, task);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('添加任务'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withOpacity(0.05),
              theme.colorScheme.secondary.withOpacity(0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 28, 18, 18), // 顶部加大间距
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const SizedBox(height: 24), // 让第一个输入框下移
                // 任务分组选择
                DropdownButtonFormField<String>(
                  value: _group,
                  decoration: InputDecoration(
                    labelText: '任务分组',
                    labelStyle: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary.withOpacity(0.5),
                      ),
                    ),
                    filled: true,
                    // 使用与背景一致的颜色
                    fillColor: theme.colorScheme.primary.withOpacity(0.05),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  items: [
                    ..._groups.map(
                      (g) => DropdownMenuItem(
                        value: g,
                        child: Text(
                          g,
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const DropdownMenuItem(
                      value: '➕新建分组',
                      child: Text(
                        '➕新建分组',
                        style: TextStyle(color: Colors.blueGrey),
                      ),
                    ),
                  ],
                  onChanged: (v) async {
                    if (v == '➕新建分组') {
                      await _showAddGroupDialog();
                    } else if (v != null) {
                      setState(() => _group = v);
                    }
                  },
                ),
                // 任务标题
                TextFormField(
                  decoration: InputDecoration(
                    labelText: '任务标题',
                    labelStyle: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? '请输入标题' : null,
                  onSaved: (v) => _title = v!.trim(),
                ),
                const SizedBox(height: 16),
                // 描述
                TextFormField(
                  decoration: InputDecoration(
                    labelText: '描述',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onSaved: (v) => _description = v?.trim(),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                // 优先级
                DropdownButtonFormField<int>(
                  value: _priority,
                  decoration: InputDecoration(
                    labelText: '优先级',
                    labelStyle: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 1,
                      child: Text('高', style: TextStyle(color: Colors.red)),
                    ),
                    DropdownMenuItem(
                      value: 2,
                      child: Text('中', style: TextStyle(color: Colors.orange)),
                    ),
                    DropdownMenuItem(
                      value: 3,
                      child: Text('低', style: TextStyle(color: Colors.green)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _priority = v ?? 2),
                ),
                const SizedBox(height: 16),
                // 标签
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _tagController,
                        decoration: InputDecoration(
                          labelText: '添加标签',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.blue),
                      onPressed: _addTag,
                    ),
                  ],
                ),
                Wrap(
                  spacing: 6,
                  children: _tags
                      .map(
                        (tag) => Chip(
                          label: Text(
                            tag,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          backgroundColor: theme.colorScheme.primary,
                          deleteIconColor: Colors.white,
                          onDeleted: () => setState(() => _tags.remove(tag)),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                // 截止日期
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _dueDate == null
                        ? '选择截止日期'
                        : '截止日期: ${DateFormat('yyyy-MM-dd').format(_dueDate!)}',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.calendar_today,
                    color: Colors.blue,
                  ),
                  onTap: _pickDueDate,
                ),
                const SizedBox(height: 8),
                // 提醒时间快捷选择
                Row(
                  children: [
                    Text(
                      '提醒时间:',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _quickSetReminder('明日9:00'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('明日9:00'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _quickSetReminder('下周一9:00'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.deepPurple,
                        side: const BorderSide(color: Colors.deepPurple),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('下周一9:00'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _pickRemindDateTime,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.teal,
                        side: const BorderSide(color: Colors.teal),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('自定义'),
                    ),
                  ],
                ),
                if (_remindDateTime != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '已选提醒时间: ${DateFormat('yyyy-MM-dd HH:mm').format(_remindDateTime!)}',
                      style: const TextStyle(
                        color: Colors.teal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                // 重复周期
                DropdownButtonFormField<String>(
                  value: _repeat,
                  decoration: InputDecoration(
                    labelText: '重复周期',
                    labelStyle: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: '无', child: Text('无')),
                    DropdownMenuItem(value: '每天', child: Text('每天')),
                    DropdownMenuItem(value: '工作日', child: Text('工作日')),
                    DropdownMenuItem(value: '每周', child: Text('每周')),
                    DropdownMenuItem(value: '每月', child: Text('每月')),
                    DropdownMenuItem(value: '每年', child: Text('每年')),
                  ],
                  onChanged: (v) => setState(() => _repeat = v ?? '无'),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline, size: 22),
                    label: const Text(
                      '保存',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    onPressed: _save,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
