import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../supabase/client.dart';
import '../models/task.dart';
import '../models/goal.dart';
import '../models/note.dart';
import '../models/calendar_event.dart';
import '../models/settings.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/modal_sheet.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = SupabaseService.instance;
  List<Task> _tasks = [];
  List<Transaction> _transactions = [];
  List<Goal> _goals = [];
  List<Note> _notes = [];
  List<CalendarEvent> _events = [];
  UserSettings? _settings;
  bool _loading = true;
  final _noteSearchCtrl = TextEditingController();
  String _noteSearch = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tasksRaw = await _supabase.getTasks();
      final txnsRaw = await _supabase.getTransactions();
      final goalsRaw = await _supabase.getGoals();
      final notesRaw = await _supabase.getNotes();
      final eventsRaw = await _supabase.getCalendarEvents();
      final settingsRaw = await _supabase.getSettings();

      setState(() {
        _tasks = tasksRaw.map((e) => Task.fromMap(e)).toList();
        _transactions = txnsRaw.map((e) => Transaction.fromMap(e)).toList();
        _goals = goalsRaw.map((e) => Goal.fromMap(e)).toList();
        _notes = notesRaw.map((e) => Note.fromMap(e)).toList();
        _events = eventsRaw.map((e) => CalendarEvent.fromMap(e)).toList();
        if (settingsRaw != null) _settings = UserSettings.fromMap(settingsRaw);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<Note> get _filteredNotes {
    var ns = List<Note>.from(_notes);
    ns.sort((a, b) {
      if (a.pinned && !b.pinned) return -1;
      if (!a.pinned && b.pinned) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    if (_noteSearch.isNotEmpty) {
      final q = _noteSearch.toLowerCase();
      ns = ns.where((n) =>
        n.title.toLowerCase().contains(q) || n.body.toLowerCase().contains(q)
      ).toList();
    }
    return ns;
  }

  Future<void> _addNote(String title, String body, List<String> tags) async {
    final userId = _supabase.client.auth.currentUser?.id;
    if (userId == null) return;
    final note = Note(
      id: const Uuid().v4(), userId: userId, title: title,
      body: body, tags: List.from(tags),
    );
    await _supabase.addNote(note.toMap());
    _load();
  }

  Future<void> _deleteNote(String id) async {
    await _supabase.deleteNote(id);
    _load();
  }

  Future<void> _togglePinNote(String id) async {
    final note = _notes.firstWhere((n) => n.id == id);
    await _supabase.updateNote(id, {'pinned': !note.pinned});
    _load();
  }

  void _showAddNoteSheet() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    List<String> selectedTags = [];

    AppModalSheet.show(context, 'New Note', StatefulBuilder(
      builder: (context, setSheetState) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Note title',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[200]!)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bodyCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Write your note...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[200]!)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: noteTags.map((tag) {
                final selected = selectedTags.contains(tag);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setSheetState(() {
                      if (selected) {
                        selectedTags.remove(tag);
                      } else {
                        selectedTags.add(tag);
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? AppTheme.primary : Colors.grey[200]!),
                      ),
                      child: Text(tag,
                        style: TextStyle(fontSize: 11,
                          color: selected ? Colors.white : Colors.grey[500])),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final title = titleCtrl.text.trim();
                  if (title.isEmpty) return;
                  _addNote(title, bodyCtrl.text.trim(), selectedTags);
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                child: const Text('Save Note'),
              ),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _tagBadge(String tag) {
    final colors = {
      'DSA': Colors.purple,
      'Finance': AppTheme.highlight,
      'College': Colors.blue,
      'Ideas': Colors.orange,
      'Personal': Colors.pink,
    };
    final c = colors[tag] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(tag, style: TextStyle(fontSize: 9, color: c, fontWeight: FontWeight.w500)),
    );
  }

  String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _monthStr() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  int _daysBetween(String a, String b) {
    final ad = DateTime.parse(a);
    final bd = DateTime.parse(b);
    return bd.difference(ad).inDays;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final today = _today();
    final month = _monthStr();
    final pendingTasks = _tasks.where((t) => !t.done && t.date == today).length;
    final monthTxns = _transactions.where((t) => t.date.startsWith(month)).toList();
    final monthIn = monthTxns.where((t) => t.type == 'income').fold<double>(0, (s, t) => s + t.amount);
    final monthOut = monthTxns.where((t) => t.type == 'expense').fold<double>(0, (s, t) => s + t.amount);
    final net = monthIn - monthOut;
    final budget = _settings?.monthlyBudget ?? 0;
    final budgetPercent = budget > 0 ? (monthOut / budget * 100).clamp(0, 100) : 0.0;
    final budgetWarning = budget > 0 && monthOut > budget;

    // streak
    final doneDates = <String>{};
    for (final t in _tasks) {
      if (t.completedDates.isNotEmpty) doneDates.addAll(t.completedDates);
    }
    int streak = 0;
    if (doneDates.isNotEmpty) {
      final sorted = doneDates.toList()..sort((a, b) => b.compareTo(a));
      var cur = today;
      for (final d in sorted) {
        if (d == cur) {
          streak++;
          cur = _addDays(cur, -1);
        } else if (streak == 0 && d.compareTo(cur) < 0) {
          break;
        } else {
          break;
        }
      }
      if (sorted.first != today && _daysBetween(sorted.first, today) > 1) streak = 0;
    }

    final now = today;
    final upcomingGoals = _goals.where((g) =>
      !g.completed && g.deadline != null && g.deadline!.compareTo(now) >= 0 &&
      _daysBetween(now, g.deadline!) <= 7
    ).toList();
    final todayEvents = _events.where((e) => e.date == today).toList();
    final upcomingEvents = _events.where((e) =>
      e.date.compareTo(now) > 0 && _daysBetween(now, e.date) <= 7
    ).toList()..sort((a, b) => a.date.compareTo(b.date));

    final greeting = _greeting();
    final formattedDate = DateFormat('EEE, d MMM yyyy').format(DateTime.now());

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          // Top Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Image.asset('assets/logo.png', width: 26, height: 26),
                  const SizedBox(width: 8),
                  const Text(
                    'LifeSync',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: AppTheme.primary, size: 20),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ).then((_) => setState(() {})),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Greeting
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[100]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(formattedDate, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                      const SizedBox(height: 4),
                      Text('$greeting, ${_settings?.name ?? 'Darshan'}.',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _statChip(Icons.check_box_outlined, '$pendingTasks pending'),
                          const SizedBox(width: 12),
                          _statChip(Icons.bolt, '$streak day streak'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.highlight.withValues(alpha: 0.15),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                  ),
                ),
              ],
            ),
          ),

          // Today's Events
          if (todayEvents.isNotEmpty) ...[
            const SizedBox(height: 12),
            _sectionCard('Today\'s Events', Icons.event, [
              for (final e in todayEvents)
                _eventTile(e, isToday: true),
            ]),
          ],

          const SizedBox(height: 12),

          // Quick Stats — totals & collective only
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: _cardDecor(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SPENT THIS MONTH', style: TextStyle(fontSize: 9, letterSpacing: 1, color: Colors.grey[400], fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text('${AppTheme.rupee}${monthOut.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600,
                          color: budgetWarning ? AppTheme.warning : AppTheme.textPrimary)),
                      if (budget > 0) ...[
                        const SizedBox(height: 8),
                        Row(children: [
                          Text('${budgetPercent.toStringAsFixed(0)}% of budget',
                            style: TextStyle(fontSize: 9, color: Colors.grey[400])),
                          const Spacer(),
                          Text(budgetWarning ? 'Exceeded!' : 'On track',
                            style: TextStyle(fontSize: 9, color: budgetWarning ? AppTheme.warning : AppTheme.success)),
                        ]),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: budgetPercent / 100,
                            backgroundColor: Colors.grey[100],
                            valueColor: AlwaysStoppedAnimation(budgetWarning ? AppTheme.warning : AppTheme.success),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: _cardDecor(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('NET SAVED', style: TextStyle(fontSize: 9, letterSpacing: 1, color: Colors.grey[400], fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text('${net >= 0 ? '+' : ''}${AppTheme.rupee}${net.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600,
                          color: net >= 0 ? AppTheme.success : AppTheme.warning)),
                      const SizedBox(height: 4),
                      Text('${AppTheme.rupee}${monthIn.toStringAsFixed(0)} in / ${AppTheme.rupee}${monthOut.toStringAsFixed(0)} out',
                        style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Notes Section
          const SizedBox(height: 12),
          _buildNotesSection(),

          // Upcoming
          if (upcomingGoals.isNotEmpty || upcomingEvents.isNotEmpty) ...[
            const SizedBox(height: 12),
            _sectionCard('Upcoming (7 days)', Icons.calendar_today, [
              for (final g in upcomingGoals)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.warning),
                      const SizedBox(width: 8),
                      Expanded(child: Text(g.title, style: const TextStyle(fontSize: 13))),
                      Text(DateFormat('d MMM').format(DateTime.parse(g.deadline!)),
                        style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                    ],
                  ),
                ),
              for (final e in upcomingEvents)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.calendarTypeColors[e.eventType],
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: Text(e.title, style: const TextStyle(fontSize: 13))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.calendarTypeColors[e.eventType]!.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(e.eventType, style: TextStyle(fontSize: 9, color: AppTheme.calendarTypeColors[e.eventType])),
                      ),
                      const SizedBox(width: 8),
                      Text(DateFormat('d MMM').format(DateTime.parse(e.date)),
                        style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                    ],
                  ),
                ),
            ]),
          ],

          // Today's Tasks
          const SizedBox(height: 12),
          _sectionCard('Today\'s Tasks', Icons.check_box_outlined, [
            if (_tasks.where((t) => t.date == today).isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No tasks for today.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              )
            else
              for (final t in _tasks.where((t) => t.date == today).take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(t.done ? Icons.check_circle : Icons.circle_outlined,
                        size: 16, color: t.done ? AppTheme.success : Colors.grey[300]),
                      const SizedBox(width: 8),
                      Text(t.text,
                        style: TextStyle(
                          fontSize: 13,
                          decoration: t.done ? TextDecoration.lineThrough : null,
                          color: t.done ? Colors.grey[400] : AppTheme.textPrimary,
                        )),
                    ],
                  ),
                ),
            if (_tasks.where((t) => t.date == today).length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('+${_tasks.where((t) => t.date == today).length - 5} more',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              ),
          ]),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    final filtered = _filteredNotes;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecor(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined, size: 12, color: Colors.grey[400]),
              const SizedBox(width: 6),
              Text('NOTES',
                style: TextStyle(fontSize: 9, letterSpacing: 1, color: Colors.grey[400], fontWeight: FontWeight.w500)),
              const Spacer(),
              GestureDetector(
                onTap: _showAddNoteSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 12, color: Colors.white),
                      SizedBox(width: 2),
                      Text('Note', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteSearchCtrl,
            onChanged: (v) => setState(() => _noteSearch = v),
            decoration: InputDecoration(
              hintText: 'Search notes...',
              prefixIcon: Icon(Icons.search, size: 14, color: Colors.grey[400]),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[200]!)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              isDense: true,
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
          const SizedBox(height: 8),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: EmptyState(
                icon: Icons.description_outlined,
                title: _noteSearch.isNotEmpty ? 'No matching notes' : 'No notes yet',
                description: _noteSearch.isNotEmpty ? 'Try a different search' : 'Tap + to create one',
              ),
            )
          else
            ...List.generate(filtered.length, (i) {
              final n = filtered[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: n.pinned ? AppTheme.highlight.withValues(alpha: 0.15) : Colors.transparent,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (n.pinned)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Icon(Icons.push_pin, size: 12, color: AppTheme.highlight),
                                ),
                              Expanded(
                                child: Text(n.title,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                          if (n.body.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(n.body,
                                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4, runSpacing: 2,
                            children: [
                              for (final tag in n.tags)
                                _tagBadge(tag),
                              Text(DateFormat('d MMM').format(DateTime.parse(n.createdAt)),
                                style: TextStyle(fontSize: 9, color: Colors.grey[400])),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        GestureDetector(
                          onTap: () => _togglePinNote(n.id),
                          child: Icon(
                            n.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                            size: 14, color: n.pinned ? AppTheme.highlight : Colors.grey[300],
                          ),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => _deleteNote(n.id),
                          child: Icon(Icons.close, size: 14, color: Colors.grey[300]),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ],
    );
  }

  Widget _sectionCard(String title, IconData icon, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecor(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: Colors.grey[400]),
              const SizedBox(width: 6),
              Text(title.toUpperCase(),
                style: TextStyle(fontSize: 9, letterSpacing: 1, color: Colors.grey[400], fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _eventTile(CalendarEvent e, {bool isToday = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.calendarTypeColors[e.eventType],
          )),
          const SizedBox(width: 8),
          Expanded(child: Text(e.title, style: const TextStyle(fontSize: 13))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.calendarTypeColors[e.eventType]!.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(e.eventType,
              style: TextStyle(fontSize: 9, color: AppTheme.calendarTypeColors[e.eventType])),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecor() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.grey[100]!),
  );

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _addDays(String d, int n) {
    final date = DateTime.parse(d).add(Duration(days: n));
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
