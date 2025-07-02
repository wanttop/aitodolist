import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/task.dart';
import '../services/task_storage.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late Map<DateTime, List<Task>> _tasksByDay;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Task> _selectedTasks = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final tasks = await TaskStorage.loadTasks();
    _tasksByDay = {};
    for (var t in tasks) {
      final day = DateTime(
          t.dueDate?.year ?? 0, t.dueDate?.month ?? 0, t.dueDate?.day ?? 0);
      if (!_tasksByDay.containsKey(day)) _tasksByDay[day] = [];
      _tasksByDay[day]!.add(t);
    }
    setState(() {});
  }

  List<Task> _getTasksForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _tasksByDay[key] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('日历')),
      body: Column(
        children: [
          TableCalendar<Task>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2100, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: _getTasksForDay,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
                _selectedTasks = _getTasksForDay(selectedDay);
              });
              showModalBottomSheet(
                context: context,
                builder: (_) => ListView(
                  children: _selectedTasks
                      .map((task) => ListTile(title: Text(task.title)))
                      .toList(),
                ),
              );
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isNotEmpty) {
                  return Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${events.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  );
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }
}
