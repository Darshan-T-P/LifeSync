import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../supabase/client.dart';
import '../models/goal.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/progress_bar.dart';
import '../widgets/modal_sheet.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final _supabase = SupabaseService.instance;
  List<Goal> _goals = [];
  bool _loading = true;
  String? _celebrated;

  // Add form
  final _titleCtrl = TextEditingController();
  String _deadline = '';
  String _goalType = 'short-term';
  List<GoalSubtask> _newSubtasks = [];
  final _subCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final raw = await _supabase.getGoals();
      setState(() {
        _goals = raw.map((e) => Goal.fromMap(e)).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _addGoal() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    final userId = _supabase.client.auth.currentUser?.id;
    if (userId == null) return;
    final goalId = const Uuid().v4();
    final goal = Goal(
      id: goalId, userId: userId, title: title,
      deadline: _deadline.isEmpty ? null : _deadline,
      goalType: _goalType,
    );
    await _supabase.addGoal(goal.toMap());
    for (final s in _newSubtasks) {
      await _supabase.addSubtask(GoalSubtask(id: const Uuid().v4(), goalId: goalId, text: s.text).toMap());
    }
    _titleCtrl.clear();
    _deadline = '';
    _goalType = 'short-term';
    _newSubtasks = [];
    if (!mounted) return;
    Navigator.pop(context);
    _load();
  }

  Future<void> _toggleGoal(String id) async {
    final goal = _goals.firstWhere((g) => g.id == id);
    final completed = !goal.completed;
    if (completed) setState(() => _celebrated = id);
    await _supabase.updateGoal(id, {
      'completed': completed,
      'progress': completed ? 100 : goal.progress,
    });
    _load();
  }

  Future<void> _delete(String id) async {
    await _supabase.deleteGoal(id);
    _load();
  }

  Future<void> _updateProgress(String id, int progress) async {
    await _supabase.updateGoal(id, {
      'progress': progress.clamp(0, 100),
      'completed': progress >= 100,
    });
    _load();
  }

  void _addSubtask() {
    final t = _subCtrl.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _newSubtasks.add(GoalSubtask(id: '', text: t));
      _subCtrl.clear();
    });
  }

  void _removeSub(int i) => setState(() => _newSubtasks.removeAt(i));

  int _calcProgress(Goal g) {
    if (g.subtasks.isEmpty) return g.progress;
    final done = g.subtasks.where((s) => s.done).length;
    return ((done / g.subtasks.length) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Goals', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                FilledButton.icon(
                  onPressed: _showAddSheet,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),

          // Celebration
          if (_celebrated != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.highlight.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.highlight.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Icon(Icons.auto_awesome, size: 24, color: AppTheme.highlight),
                  const SizedBox(height: 8),
                  const Text('Goal completed! Great work!',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.highlight)),
                  TextButton(
                    onPressed: () => setState(() => _celebrated = null),
                    child: const Text('Dismiss', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),

          if (_celebrated != null) const SizedBox(height: 8),

          // List
          Expanded(
            child: _goals.isEmpty
                ? const EmptyState(icon: Icons.track_changes, title: 'No goals yet', description: 'Set a goal to track your progress')
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _goals.length,
                    itemBuilder: (_, i) {
                      final g = _goals[i];
                      final p = _calcProgress(g);
                      final daysLeft = g.deadline != null
                          ? DateTime.parse(g.deadline!).difference(DateTime.now()).inDays
                          : null;
                      final overdue = daysLeft != null && daysLeft < 0 && !g.completed;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: g.completed ? AppTheme.success.withValues(alpha: 0.05) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: g.completed ? AppTheme.success.withValues(alpha: 0.3) : Colors.grey[100]!,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () => _toggleGoal(g.id),
                              child: Icon(
                                g.completed ? Icons.check_circle : Icons.circle_outlined,
                                size: 20, color: g.completed ? AppTheme.success : Colors.grey[300],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(g.title,
                                    style: TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w500,
                                      decoration: g.completed ? TextDecoration.lineThrough : null,
                                      color: g.completed ? Colors.grey[400] : AppTheme.textPrimary,
                                    )),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 6, runSpacing: 4,
                                    children: [
                                      _badge(g.goalType == 'short-term' ? 'Short-term' : 'Long-term',
                                          g.goalType == 'short-term' ? Colors.green : Colors.blue),
                                      if (daysLeft != null)
                                        Text(
                                          overdue ? 'Overdue by ${daysLeft.abs()}d' : '${daysLeft}d left',
                                          style: TextStyle(fontSize: 10, color: overdue ? AppTheme.warning : Colors.grey[400]),
                                        ),
                                      if (g.deadline != null)
                                        Text(DateFormat('d MMM').format(DateTime.parse(g.deadline!)),
                                          style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(child: ProgressBar(value: p.toDouble())),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 32,
                                        child: Text('$p%', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                                      ),
                                    ],
                                  ),
                                  if (!g.completed) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Slider(
                                            value: g.progress.toDouble(),
                                            min: 0, max: 100,
                                            divisions: 100,
                                            activeColor: AppTheme.highlight,
                                            onChanged: (v) => _updateProgress(g.id, v.round()),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 48,
                                          child: TextField(
                                            controller: TextEditingController(text: g.progress.toString()),
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(fontSize: 12),
                                            decoration: InputDecoration(
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey[200]!)),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                              isDense: true,
                                            ),
                                            onSubmitted: (v) => _updateProgress(g.id, int.tryParse(v) ?? 0),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  // Subtasks
                                  if (g.subtasks.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    for (final s in g.subtasks)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 2),
                                        child: Row(
                                          children: [
                                            Icon(s.done ? Icons.check : Icons.circle_outlined,
                                              size: 12, color: s.done ? AppTheme.success : Colors.grey[300]),
                                            const SizedBox(width: 6),
                                            Text(s.text,
                                              style: TextStyle(
                                                fontSize: 11,
                                                decoration: s.done ? TextDecoration.lineThrough : null,
                                                color: s.done ? Colors.grey[400] : Colors.grey[600],
                                              )),
                                          ],
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _delete(g.id),
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
    _titleCtrl.clear();
    _subCtrl.clear();
    _deadline = DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 30)));
    _goalType = 'short-term';
    _newSubtasks = [];

    AppModalSheet.show(context, 'New Goal', StatefulBuilder(
      builder: (context, setSheetState) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Goal title',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[200]!)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Deadline', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                      const SizedBox(height: 4),
                      TextField(
                        controller: TextEditingController(text: _deadline),
                        readOnly: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[200]!)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                          suffixIcon: Icon(Icons.calendar_today, size: 16, color: Colors.grey[400]),
                        ),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.parse(_deadline),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                          );
                          if (date != null) setSheetState(() => _deadline = DateFormat('yyyy-MM-dd').format(date));
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Type', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: _goalType,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[200]!)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(value: 'short-term', child: Text('Short-term', style: TextStyle(fontSize: 13))),
                          const DropdownMenuItem(value: 'long-term', child: Text('Long-term', style: TextStyle(fontSize: 13))),
                        ],
                        onChanged: (v) => setSheetState(() => _goalType = v!),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Subtasks
            ..._newSubtasks.asMap().entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.circle_outlined, size: 12, color: Colors.grey[300]),
                  const SizedBox(width: 8),
                  Text(entry.value.text, style: const TextStyle(fontSize: 12)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setSheetState(() => _removeSub(entry.key)),
                    child: Icon(Icons.close, size: 14, color: Colors.grey[300]),
                  ),
                ],
              ),
            )),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subCtrl,
                    decoration: InputDecoration(
                      hintText: 'Add sub-task',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[200]!)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    onSubmitted: (_) => setSheetState(_addSubtask),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setSheetState(_addSubtask),
                  child: const Text('Add', style: TextStyle(color: AppTheme.highlight)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _addGoal,
                child: const Text('Create Goal'),
                style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
              ),
            ),
          ],
        ),
      ),
    ));
  }
}
