class GoalSubtask {
  final String id;
  final String goalId;
  final String text;
  final bool done;

  GoalSubtask({required this.id, this.goalId = '', required this.text, this.done = false});

  factory GoalSubtask.fromMap(Map<String, dynamic> map) {
    return GoalSubtask(
      id: map['id'] as String,
      goalId: (map['goal_id'] as String?) ?? '',
      text: map['text'] as String,
      done: (map['done'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    if (id.isNotEmpty) 'id': id,
    'goal_id': goalId,
    'text': text,
    'done': done,
  };

  GoalSubtask copyWith({String? text, bool? done}) => GoalSubtask(
    id: id, goalId: goalId, text: text ?? this.text, done: done ?? this.done,
  );
}

class Goal {
  final String id;
  final String userId;
  final String title;
  final String? deadline;
  final int progress;
  final String goalType; // short-term / long-term
  final bool completed;
  final String createdAt;
  final List<GoalSubtask> subtasks;

  Goal({
    required this.id,
    required this.userId,
    required this.title,
    this.deadline,
    this.progress = 0,
    this.goalType = 'short-term',
    this.completed = false,
    String? createdAt,
    List<GoalSubtask>? subtasks,
  }) : createdAt = createdAt ?? _today(),
       subtasks = subtasks ?? [];

  static String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  factory Goal.fromMap(Map<String, dynamic> map) {
    List<GoalSubtask> subs = [];
    if (map['goal_subtasks'] != null) {
      subs = (map['goal_subtasks'] as List<dynamic>)
          .map((e) => GoalSubtask.fromMap(e as Map<String, dynamic>))
          .toList();
    }
    return Goal(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      deadline: map['deadline'] as String?,
      progress: (map['progress'] as num?)?.toInt() ?? 0,
      goalType: (map['goal_type'] as String?) ?? 'short-term',
      completed: (map['completed'] as bool?) ?? false,
      createdAt: map['created_at'] as String?,
      subtasks: subs,
    );
  }

  Map<String, dynamic> toMap() => {
    if (id.isNotEmpty) 'id': id,
    'user_id': userId,
    'title': title,
    'deadline': deadline,
    'progress': progress,
    'goal_type': goalType,
    'completed': completed,
    'created_at': createdAt,
  };
}
