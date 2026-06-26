import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../supabase/client.dart';
import '../models/calendar_event.dart';
import '../theme/app_theme.dart';
import '../widgets/modal_sheet.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _supabase = SupabaseService.instance;
  List<CalendarEvent> _events = [];
  bool _loading = true;
  late DateTime _viewDate;
  String? _selectedDate;
  final Map<String, bool> _filters = {
    'Personal': true, 'Placement': true, 'Coding Practice': true,
  };

  // Add form
  final _titleCtrl = TextEditingController();
  String _newType = 'Personal';
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewDate = DateTime.now();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final raw = await _supabase.getCalendarEvents();
      setState(() {
        _events = raw.map((e) => CalendarEvent.fromMap(e)).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _addEvent() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty || _selectedDate == null) return;
    final userId = _supabase.client.auth.currentUser?.id;
    if (userId == null) return;
    final event = CalendarEvent(
      id: const Uuid().v4(), userId: userId, title: title,
      date: _selectedDate!, eventType: _newType, note: _noteCtrl.text.trim(),
    );
    await _supabase.addCalendarEvent(event.toMap());
    _titleCtrl.clear();
    _noteCtrl.clear();
    _newType = 'Personal';
    if (!mounted) return;
    Navigator.pop(context);
    _load();
  }

  Future<void> _delete(String id) async {
    await _supabase.deleteCalendarEvent(id);
    _load();
  }

  List<CalendarEvent> _eventsForDate(String date) =>
      _events.where((e) => e.date == date).toList();

  List<CalendarEvent> _filteredEventsForDate(String date) =>
      _events.where((e) => e.date == date && (_filters[e.eventType] ?? true)).toList();

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final year = _viewDate.year;
    final month = _viewDate.month;
    final firstDay = DateTime(year, month, 1).weekday % 7; // Sunday = 0
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Build grid
    final cells = <_CalCell>[];
    final prevMonthDays = DateTime(year, month, 0).day;
    for (int i = firstDay - 1; i >= 0; i--) {
      cells.add(_CalCell(day: prevMonthDays - i, other: true));
    }
    for (int i = 1; i <= daysInMonth; i++) {
      final dateStr = '$year-${month.toString().padLeft(2, '0')}-${i.toString().padLeft(2, '0')}';
      final dayEvents = _filteredEventsForDate(dateStr);
      cells.add(_CalCell(day: i, date: dateStr, events: dayEvents));
    }
    while (cells.length < 42) {
      cells.add(_CalCell(day: cells.length - firstDay - daysInMonth + 1, other: true));
    }

    final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final monthName = DateFormat('MMMM yyyy').format(_viewDate);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Calendar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                FilledButton.icon(
                  onPressed: () {
                    setState(() => _selectedDate = todayStr);
                    _showAddSheet();
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Event', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Type Filters
            Wrap(
              spacing: 8, runSpacing: 6,
              children: calendarTypes.map((type) {
                final active = _filters[type] ?? true;
                return GestureDetector(
                  onTap: () => setState(() => _filters[type] = !active),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: active ? AppTheme.calendarTypeColors[type] : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: active ? Colors.transparent : Colors.grey[200]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active ? Colors.white.withValues(alpha: 0.8) : AppTheme.calendarTypeColors[type],
                        )),
                        const SizedBox(width: 6),
                        Text(type,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                            color: active ? Colors.white : Colors.grey[500])),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 12),

            // Calendar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[100]!),
              ),
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _viewDate = DateTime(year, month - 1, 1)),
                          child: Icon(Icons.chevron_left, size: 20, color: Colors.grey[400]),
                        ),
                        Row(
                          children: [
                            Text(monthName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => setState(() {
                                _viewDate = DateTime.now();
                                _selectedDate = todayStr;
                              }),
                              child: Text('Today',
                                style: TextStyle(fontSize: 11, color: AppTheme.highlight, fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _viewDate = DateTime(year, month + 1, 1)),
                          child: Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  ),

                  // Day names
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: dayNames.map((d) => Expanded(
                        child: Center(
                          child: Text(d,
                            style: TextStyle(fontSize: 10, color: Colors.grey[400], fontWeight: FontWeight.w500)),
                        ),
                      )).toList(),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Grid
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Wrap(
                      children: cells.map((cell) {
                        final isToday = cell.date == todayStr;
                        final isSelected = cell.date == _selectedDate;
                        return GestureDetector(
                          onTap: () => cell.date != null
                              ? setState(() => _selectedDate = cell.date)
                              : null,
                          child: Container(
                            width: (MediaQuery.of(context).size.width - 48) / 7,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              children: [
                                Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isToday ? AppTheme.primary : (isSelected ? Colors.grey[100] : null),
                                  ),
                                  child: Center(
                                    child: Text('${cell.day}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                        color: cell.other ? Colors.grey[300] : (isToday ? Colors.white : AppTheme.textPrimary),
                                      )),
                                  ),
                                ),
                                if (cell.events.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: cell.events.take(3).map((e) => Container(
                                        width: 6, height: 6, margin: const EdgeInsets.only(right: 1),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppTheme.calendarTypeColors[e.eventType],
                                        ),
                                      )).toList(),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Selected Day Events
            if (_selectedDate != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[100]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('EEE, d MMM yyyy').format(DateTime.parse(_selectedDate!)),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        GestureDetector(
                          onTap: _showAddSheet,
                          child: Text('+ Add',
                            style: TextStyle(fontSize: 12, color: AppTheme.highlight, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...() {
                      final dayEvents = _eventsForDate(_selectedDate!);
                      if (dayEvents.isEmpty) {
                        return [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text('No events on this day.', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                          ),
                        ];
                      }
                      return dayEvents.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(width: 10, height: 10, decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.calendarTypeColors[e.eventType],
                            )),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Row(
                                children: [
                                  Text(e.title, style: const TextStyle(fontSize: 13)),
                                  const SizedBox(width: 8),
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
                            ),
                            if (e.note.isNotEmpty)
                              Text(e.note, style: TextStyle(fontSize: 11, color: Colors.grey[400]), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _delete(e.id),
                              child: Icon(Icons.close, size: 14, color: Colors.grey[300]),
                            ),
                          ],
                        ),
                      ));
                    }(),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Monthly Summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[100]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('THIS MONTH SUMMARY'.toUpperCase(),
                    style: TextStyle(fontSize: 9, letterSpacing: 1, color: Colors.grey[400], fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  for (final type in calendarTypes) ...[
                    () {
                      final count = _events.where((e) {
                        return e.date.startsWith('$year-${month.toString().padLeft(2, '0')}')
                            && e.eventType == type;
                      }).length;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Container(width: 10, height: 10, decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.calendarTypeColors[type],
                            )),
                            const SizedBox(width: 8),
                            Expanded(child: Text(type, style: const TextStyle(fontSize: 13))),
                            Text('$count event${count != 1 ? 's' : ''}',
                              style: const TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                      );
                    }(),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showAddSheet() {
    _titleCtrl.clear();
    _noteCtrl.clear();
    _newType = 'Personal';

    AppModalSheet.show(context, 'Add Event', StatefulBuilder(
      builder: (context, setSheetState) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleCtrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Event title',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[200]!)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: calendarTypes.map((type) {
              final active = _newType == type;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: type != calendarTypes.last ? 6 : 0),
                  child: GestureDetector(
                    onTap: () => setSheetState(() => _newType = type),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: active ? AppTheme.calendarTypeColors[type] : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: active ? Colors.transparent : Colors.grey[200]!),
                      ),
                      child: Center(
                        child: Text(type,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                            color: active ? Colors.white : Colors.grey[500])),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: TextEditingController(text: _selectedDate),
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Date',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[200]!)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: InputDecoration(
              hintText: 'Note (optional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[200]!)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _addEvent,
              child: const Text('Add Event'),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            ),
          ),
        ],
      ),
    ));
  }
}

class _CalCell {
  final int day;
  final String? date;
  final bool other;
  final List<CalendarEvent> events;

  _CalCell({required this.day, this.date, this.other = false, this.events = const []});
}
