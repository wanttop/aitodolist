class Task {
  String id;
  String title;
  String? description;
  DateTime? dueDate;
  bool isDone;
  int priority; // 1=高, 2=中, 3=低
  List<String> tags;

  Task({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    this.isDone = false,
    this.priority = 2, // 默认中优先级
    List<String>? tags,
  }) : tags = tags ?? [];

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        dueDate:
            json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
        isDone: json['isDone'] ?? false,
        priority: json['priority'] ?? 2,
        tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'dueDate': dueDate?.toIso8601String(),
        'isDone': isDone,
        'priority': priority,
        'tags': tags,
      };

  Task copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dueDate,
    bool? isDone,
    int? priority,
    List<String>? tags,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      isDone: isDone ?? this.isDone,
      priority: priority ?? this.priority,
      tags: tags ?? List<String>.from(this.tags),
    );
  }
}
