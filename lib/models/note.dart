class Note {
  final String id;
  final String userId;
  final String title;
  final String body;
  final List<String> tags;
  final bool pinned;
  final String createdAt;

  Note({
    required this.id,
    required this.userId,
    required this.title,
    this.body = '',
    List<String>? tags,
    this.pinned = false,
    String? createdAt,
  }) : tags = tags ?? [],
       createdAt = createdAt ?? _today();

  static String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      body: (map['body'] as String?) ?? '',
      tags: (map['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      pinned: (map['pinned'] as bool?) ?? false,
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    if (id.isNotEmpty) 'id': id,
    'user_id': userId,
    'title': title,
    'body': body,
    'tags': tags,
    'pinned': pinned,
    'created_at': createdAt,
  };

  Note copyWith({String? title, String? body, List<String>? tags, bool? pinned}) =>
      Note(id: id, userId: userId, title: title ?? this.title, body: body ?? this.body,
           tags: tags ?? this.tags, pinned: pinned ?? this.pinned, createdAt: createdAt);
}

const List<String> noteTags = ['DSA', 'Finance', 'College', 'Ideas', 'Personal'];
