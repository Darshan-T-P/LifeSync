class Task {
  final String id;
  final String userId;
  final String text;
  final bool done;
  final String priority;
  final String category;
  final String? recurring;
  final bool isFocus;
  final String date;
  final String createdAt;
  final List<String> completedDates;

  Task({
    required this.id,
    required this.userId,
    required this.text,
    this.done = false,
    this.priority = 'medium',
    this.category = 'Personal',
    this.recurring,
    this.isFocus = false,
    String? date,
    String? createdAt,
    List<String>? completedDates,
  }) : date = date ?? _today(),
       createdAt = createdAt ?? _today(),
       completedDates = completedDates ?? [];

  static String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      text: map['text'] as String,
      done: (map['done'] as bool?) ?? false,
      priority: (map['priority'] as String?) ?? 'medium',
      category: (map['category'] as String?) ?? 'Personal',
      recurring: map['recurring'] as String?,
      isFocus: (map['is_focus'] as bool?) ?? false,
      date: map['date'] as String?,
      createdAt: map['created_at'] as String?,
      completedDates: (map['completed_dates'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toMap() => {
    if (id.isNotEmpty) 'id': id,
    'user_id': userId,
    'text': text,
    'done': done,
    'priority': priority,
    'category': category,
    'recurring': recurring,
    'is_focus': isFocus,
    'date': date,
    'created_at': createdAt,
    'completed_dates': completedDates,
  };

  Task copyWith({
    String? text,
    bool? done,
    String? priority,
    String? category,
    String? recurring,
    bool? isFocus,
    String? date,
    List<String>? completedDates,
  }) => Task(
    id: id,
    userId: userId,
    text: text ?? this.text,
    done: done ?? this.done,
    priority: priority ?? this.priority,
    category: category ?? this.category,
    recurring: recurring ?? this.recurring,
    isFocus: isFocus ?? this.isFocus,
    date: date ?? this.date,
    createdAt: createdAt,
    completedDates: completedDates ?? this.completedDates,
  );
}
