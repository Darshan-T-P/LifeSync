class CalendarEvent {
  final String id;
  final String userId;
  final String title;
  final String date;
  final String eventType; // Personal / Placement / Coding Practice
  final String note;
  final String createdAt;

  CalendarEvent({
    required this.id,
    required this.userId,
    required this.title,
    required this.date,
    required this.eventType,
    this.note = '',
    String? createdAt,
  }) : createdAt = createdAt ?? _today();

  static String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  factory CalendarEvent.fromMap(Map<String, dynamic> map) {
    return CalendarEvent(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      date: map['date'] as String,
      eventType: map['event_type'] as String,
      note: (map['note'] as String?) ?? '',
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    if (id.isNotEmpty) 'id': id,
    'user_id': userId,
    'title': title,
    'date': date,
    'event_type': eventType,
    'note': note,
    'created_at': createdAt,
  };
}

const List<String> calendarTypes = ['Personal', 'Placement', 'Coding Practice'];
