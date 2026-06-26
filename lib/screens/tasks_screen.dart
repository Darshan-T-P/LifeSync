import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../supabase/client.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';
import '../theme/app_settings.dart';
import '../widgets/empty_state.dart';
import '../widgets/modal_sheet.dart';

const List<String> _priorities = ['high', 'medium', 'low'];
const List<String> _categories = ['College', 'DSA', 'Project', 'Personal', 'Placement'];

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _supabase = SupabaseService.instance;
  List<Task> _tasks = [];
  bool _loading = true;
  String _filter = 'all';

  // Add form
  final _textCtrl = TextEditingController();
  String _newPriority = 'medium';
  String _newCategory = 'Personal';
  String _newRecurring = '';
  bool _newIsFocus = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final raw = await _supabase.getTasks();
      setState(() {
        _tasks = raw.map((e) => Task.fromMap(e)).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _addTask() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    final userId = _supabase.client.auth.currentUser?.id;
    if (userId == null) return;
    final task = Task(
      id: const Uuid().v4(), userId: userId, text: text,
      priority: _newPriority, category: _newCategory,
      recurring: _newRecurring.isEmpty ? null : _newRecurring,
      isFocus: _newIsFocus,
    );
    await _supabase.addTask(task.toMap());
    _textCtrl.clear();
    _newPriority = 'medium';
    _newCategory = 'Personal';
    _newRecurring = '';
    _newIsFocus = false;
    if (!mounted) return;
    Navigator.pop(context);
    _load();
  }

  Future<void> _toggle(String id) async {
    final task = _tasks.firstWhere((t) => t.id == id);
    final done = !task.done;
    final completed = [...task.completedDates];
    if (done && !completed.contains(_today())) completed.add(_today());
    await _supabase.updateTask(id, {'done': done, 'completed_dates': completed});
    _load();
  }

  Future<void> _delete(String id) async {
    await _supabase.deleteTask(id);
    _load();
  }

  Future<void> _clearDone() async {
    for (final t in _tasks) {
      if (t.done) await _supabase.updateTask(t.id, {'done': false});
    }
    _load();
  }

  List<Task> get _filtered {
    var ts = List<Task>.from(_tasks);
    if (_filter == 'today') ts = ts.where((t) => t.date == _today()).toList();
    if (_filter == 'pending') ts = ts.where((t) => !t.done).toList();
    if (_filter == 'done') ts = ts.where((t) => t.done).toList();
    ts.sort((a, b) {
      if (a.isFocus && !b.isFocus) return -1;
      if (!a.isFocus && b.isFocus) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return ts;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final filtered = _filtered;
    final today = _today();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppSettings.translate('tasks'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    TextButton(onPressed: _clearDone, child: Text(AppSettings.translate('reset_done'), style: TextStyle(fontSize: 11, color: Colors.grey[400]))),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _showAddSheet(),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(AppSettings.translate('add'), style: const TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _filterChip('All', 'all'),
                const SizedBox(width: 4),
                _filterChip('Today', 'today'),
                const SizedBox(width: 4),
                _filterChip('Pending', 'pending'),
                const SizedBox(width: 4),
                _filterChip('Done', 'done'),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Task List
          Expanded(
            child: filtered.isEmpty
                ? EmptyState(icon: Icons.check_box_outlined, title: 'No tasks found',
                    description: _filter == 'today' ? 'Add something for today!' : 'Add your first task')
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final t = filtered[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: t.isFocus ? AppTheme.highlight.withValues(alpha: 0.3) : Colors.grey[100]!,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () => _toggle(t.id),
                              child: Icon(
                                t.done ? Icons.check_circle : Icons.circle_outlined,
                                size: 20, color: t.done ? AppTheme.success : Colors.grey[300],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (t.isFocus)
                                    Text('TODAY\'S FOCUS', style: TextStyle(fontSize: 9, letterSpacing: 1, color: AppTheme.highlight, fontWeight: FontWeight.w500)),
                                  Text(t.text,
                                    style: TextStyle(
                                      fontSize: 13,
                                      decoration: t.done ? TextDecoration.lineThrough : null,
                                      color: t.done ? Colors.grey[400] : AppTheme.textPrimary,
                                    )),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      _badge(t.priority, AppTheme.priorityColors[t.priority]!),
                                      _badge(t.category, Colors.grey[600]!),
                                      if (t.recurring != null)
                                        _badge(t.recurring!, Colors.blue),
                                      Text(t.date == today ? 'Today' : t.date,
                                        style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _delete(t.id),
                              child: Icon(Icons.close, size: 16, color: Colors.grey[300]),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final active = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? Colors.transparent : Colors.grey[200]!),
        ),
        child: Text(label,
          style: TextStyle(fontSize: 12,
            fontWeight: FontWeight.w500,
            color: active ? Colors.white : Colors.grey[500],
          )),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w500)),
    );
  }

  void _showAddSheet() {
    _textCtrl.clear();
    _newPriority = 'medium';
    _newCategory = 'Personal';
    _newRecurring = '';
    _newIsFocus = false;

    AppModalSheet.show(context, 'Add Task', StatefulBuilder(
      builder: (context, setSheetState) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _textCtrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'What do you need to do?',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[200]!)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _newPriority,
                  decoration: _fieldDec(),
                  items: _priorities.map((p) => DropdownMenuItem(value: p, child: Text(p[0].toUpperCase() + p.substring(1), style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setSheetState(() => _newPriority = v!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _newCategory,
                  decoration: _fieldDec(),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setSheetState(() => _newCategory = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _newRecurring,
            decoration: _fieldDec(),
            items: [
              const DropdownMenuItem(value: '', child: Text('One-time', style: TextStyle(fontSize: 13))),
              ...['daily', 'weekly', 'monthly'].map((r) => DropdownMenuItem(value: r, child: Text(r[0].toUpperCase() + r.substring(1), style: const TextStyle(fontSize: 13)))),
            ],
            onChanged: (v) => setSheetState(() => _newRecurring = v!),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _newIsFocus,
            onChanged: (v) => setSheetState(() => _newIsFocus = v ?? false),
            title: const Text('Pin as today\'s focus', style: TextStyle(fontSize: 13)),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
              child: FilledButton(
                onPressed: _addTask,
                style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                child: const Text('Add Task'),
            ),
          ),
        ],
      ),
    ));
  }

  InputDecoration _fieldDec() => InputDecoration(
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[200]!)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    isDense: true,
  );
}
