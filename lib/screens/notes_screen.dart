import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../supabase/client.dart';
import '../models/note.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/modal_sheet.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _supabase = SupabaseService.instance;
  List<Note> _notes = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Add form
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  List<String> _selectedTags = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final raw = await _supabase.getNotes();
      setState(() {
        _notes = raw.map((e) => Note.fromMap(e)).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _addNote() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    final userId = _supabase.client.auth.currentUser?.id;
    if (userId == null) return;
    final note = Note(
      id: const Uuid().v4(), userId: userId, title: title,
      body: _bodyCtrl.text.trim(), tags: List.from(_selectedTags),
    );
    await _supabase.addNote(note.toMap());
    _titleCtrl.clear();
    _bodyCtrl.clear();
    _selectedTags = [];
    if (!mounted) return;
    Navigator.pop(context);
    _load();
  }

  Future<void> _delete(String id) async {
    await _supabase.deleteNote(id);
    _load();
  }

  Future<void> _togglePin(String id) async {
    final note = _notes.firstWhere((n) => n.id == id);
    await _supabase.updateNote(id, {'pinned': !note.pinned});
    _load();
  }

  List<Note> get _filtered {
    var ns = List<Note>.from(_notes);
    ns.sort((a, b) {
      if (a.pinned && !b.pinned) return -1;
      if (!a.pinned && b.pinned) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      ns = ns.where((n) =>
        n.title.toLowerCase().contains(q) || n.body.toLowerCase().contains(q)
      ).toList();
    }
    return ns;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final filtered = _filtered;

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
                const Text('Quick Notes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                FilledButton.icon(
                  onPressed: _showAddSheet,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Note', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search notes...',
                prefixIcon: Icon(Icons.search, size: 16, color: Colors.grey[400]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[200]!)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // List
          Expanded(
            child: filtered.isEmpty
                ? EmptyState(
                    icon: Icons.description_outlined,
                    title: _searchQuery.isNotEmpty ? 'No matching notes' : 'No notes yet',
                    description: _searchQuery.isNotEmpty ? 'Try a different search' : 'Create your first note',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final n = filtered[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: n.pinned ? AppTheme.highlight.withValues(alpha: 0.2) : Colors.grey[100]!,
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
                                          padding: const EdgeInsets.only(right: 6),
                                          child: Icon(Icons.push_pin, size: 14, color: AppTheme.highlight),
                                        ),
                                      Expanded(
                                        child: Text(n.title,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                          maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ),
                                    ],
                                  ),
                                  if (n.body.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(n.body,
                                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                        maxLines: 3, overflow: TextOverflow.ellipsis),
                                    ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 4, runSpacing: 4,
                                    children: [
                                      for (final tag in n.tags)
                                        _tagBadge(tag),
                                      Text(DateFormat('d MMM').format(DateTime.parse(n.createdAt)),
                                        style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                GestureDetector(
                                  onTap: () => _togglePin(n.id),
                                  child: Icon(
                                    n.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                                    size: 16, color: n.pinned ? AppTheme.highlight : Colors.grey[300],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () => _delete(n.id),
                                  child: Icon(Icons.close, size: 16, color: Colors.grey[300]),
                                ),
                              ],
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

  Widget _tagBadge(String tag) {
    final colors = {
      'DSA': Colors.purple,
      'Finance': Colors.green,
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

  void _showAddSheet() {
    _titleCtrl.clear();
    _bodyCtrl.clear();
    _selectedTags = [];

    AppModalSheet.show(context, 'New Note', StatefulBuilder(
      builder: (context, setSheetState) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
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
              controller: _bodyCtrl,
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
                final selected = _selectedTags.contains(tag);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setSheetState(() {
                      if (selected) _selectedTags.remove(tag);
                      else _selectedTags.add(tag);
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
                onPressed: _addNote,
                child: const Text('Save Note'),
                style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
              ),
            ),
          ],
        ),
      ),
    ));
  }
}
