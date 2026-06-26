import 'package:flutter_test/flutter_test.dart';
import 'package:lifesync/models/task.dart';

void main() {
  group('Task', () {
    test('fromMap creates Task correctly', () {
      final map = {
        'id': '123',
        'user_id': 'user1',
        'text': 'Buy groceries',
        'done': false,
        'priority': 'high',
        'category': 'Personal',
        'recurring': null,
        'is_focus': true,
        'date': '2026-06-26',
        'created_at': '2026-06-26',
        'completed_dates': <dynamic>[],
      };

      final task = Task.fromMap(map);

      expect(task.id, '123');
      expect(task.userId, 'user1');
      expect(task.text, 'Buy groceries');
      expect(task.done, false);
      expect(task.priority, 'high');
      expect(task.category, 'Personal');
      expect(task.recurring, isNull);
      expect(task.isFocus, true);
      expect(task.date, '2026-06-26');
    });

    test('toMap converts Task correctly', () {
      final task = Task(
        id: '123',
        userId: 'user1',
        text: 'Test task',
        done: true,
        priority: 'low',
        category: 'DSA',
        recurring: 'daily',
        isFocus: false,
        date: '2026-06-26',
        createdAt: '2026-06-26',
        completedDates: ['2026-06-26'],
      );

      final map = task.toMap();

      expect(map['id'], '123');
      expect(map['user_id'], 'user1');
      expect(map['text'], 'Test task');
      expect(map['done'], true);
      expect(map['priority'], 'low');
      expect(map['category'], 'DSA');
      expect(map['recurring'], 'daily');
      expect(map['completed_dates'], ['2026-06-26']);
    });

    test('toMap excludes empty id', () {
      final task = Task(
        id: '',
        userId: 'user1',
        text: 'New task',
      );

      final map = task.toMap();

      expect(map.containsKey('id'), false);
    });

    test('copyWith overrides only specified fields', () {
      final task = Task(
        id: '1',
        userId: 'u1',
        text: 'Original',
        done: false,
        priority: 'medium',
        category: 'Personal',
      );

      final copy = task.copyWith(text: 'Updated', done: true);

      expect(copy.text, 'Updated');
      expect(copy.done, true);
      expect(copy.id, '1');
      expect(copy.priority, 'medium');
    });

    test('defaults are applied correctly', () {
      final task = Task(id: '1', userId: 'u1', text: 'Test');

      expect(task.done, false);
      expect(task.priority, 'medium');
      expect(task.category, 'Personal');
      expect(task.isFocus, false);
      expect(task.completedDates, isEmpty);
      expect(task.date, isNotEmpty);
      expect(task.createdAt, isNotEmpty);
    });
  });
}
