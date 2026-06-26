import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._();
  SupabaseService._();

  static SupabaseService get instance => _instance;

  SupabaseClient get client => Supabase.instance.client;

  Future<void> initialize() async {
    await Supabase.initialize(
      url: 'https://vhqajppzdilserxxsxgp.supabase.co',
      publishableKey: 'sb_publishable_wCcm8q0QBoWclGHHmxOjzQ_z9M5oDzJ',
    );
  }

  // -- TASKS --
  Future<List<Map<String, dynamic>>> getTasks() async {
    return client.from('tasks').select().order('date', ascending: false);
  }

  Future<void> addTask(Map<String, dynamic> task) async {
    await client.from('tasks').insert(task);
  }

  Future<void> updateTask(String id, Map<String, dynamic> updates) async {
    await client.from('tasks').update(updates).eq('id', id);
  }

  Future<void> deleteTask(String id) async {
    await client.from('tasks').delete().eq('id', id);
  }

  // -- TRANSACTIONS --
  Future<List<Map<String, dynamic>>> getTransactions() async {
    return client.from('transactions').select().order('date', ascending: false);
  }

  Future<void> addTransaction(Map<String, dynamic> txn) async {
    await client.from('transactions').insert(txn);
  }

  Future<void> deleteTransaction(String id) async {
    await client.from('transactions').delete().eq('id', id);
  }

  // -- SOURCES (cash, banks) --
  Future<List<Map<String, dynamic>>> getBanks() async {
    return client.from('banks').select().order('name', ascending: true);
  }

  Future<void> addBank(Map<String, dynamic> bank) async {
    await client.from('banks').insert(bank);
  }

  Future<void> updateBank(String id, Map<String, dynamic> updates) async {
    await client.from('banks').update(updates).eq('id', id);
  }

  Future<void> deleteBank(String id) async {
    await client.from('banks').delete().eq('id', id);
  }

  Future<Map<String, dynamic>?> getSourceByType(String userId, String sourceType) async {
    final res = await client.from('banks').select()
        .eq('user_id', userId).eq('source_type', sourceType).maybeSingle();
    return res;
  }

  Future<Map<String, dynamic>> ensureSource(String userId, String sourceType, String name) async {
    final existing = await getSourceByType(userId, sourceType);
    if (existing != null) return existing;
    final source = {
      'id': const Uuid().v4(),
      'user_id': userId,
      'name': name,
      'account_number': '',
      'balance': 0,
      'source_type': sourceType,
    };
    await client.from('banks').insert(source);
    return source;
  }

  // -- SAVINGS POTS --
  Future<List<Map<String, dynamic>>> getSavingsPots() async {
    return client.from('savings_pots').select().order('name', ascending: true);
  }

  Future<void> addSavingsPot(Map<String, dynamic> pot) async {
    await client.from('savings_pots').insert(pot);
  }

  Future<void> updateSavingsPot(String id, Map<String, dynamic> updates) async {
    await client.from('savings_pots').update(updates).eq('id', id);
  }

  Future<void> deleteSavingsPot(String id) async {
    await client.from('savings_pots').delete().eq('id', id);
  }

  // -- GOALS --
  Future<List<Map<String, dynamic>>> getGoals() async {
    return client.from('goals').select('*, goal_subtasks(*)').order('created_at', ascending: false);
  }

  Future<void> addGoal(Map<String, dynamic> goal) async {
    await client.from('goals').insert(goal);
  }

  Future<void> updateGoal(String id, Map<String, dynamic> updates) async {
    await client.from('goals').update(updates).eq('id', id);
  }

  Future<void> deleteGoal(String id) async {
    await client.from('goal_subtasks').delete().eq('goal_id', id);
    await client.from('goals').delete().eq('id', id);
  }

  Future<void> addSubtask(Map<String, dynamic> subtask) async {
    await client.from('goal_subtasks').insert(subtask);
  }

  Future<void> updateSubtask(String id, Map<String, dynamic> updates) async {
    await client.from('goal_subtasks').update(updates).eq('id', id);
  }

  Future<void> deleteSubtask(String id) async {
    await client.from('goal_subtasks').delete().eq('id', id);
  }

  // -- NOTES --
  Future<List<Map<String, dynamic>>> getNotes() async {
    return client.from('notes').select().order('pinned', ascending: false).order('created_at', ascending: false);
  }

  Future<void> addNote(Map<String, dynamic> note) async {
    await client.from('notes').insert(note);
  }

  Future<void> updateNote(String id, Map<String, dynamic> updates) async {
    await client.from('notes').update(updates).eq('id', id);
  }

  Future<void> deleteNote(String id) async {
    await client.from('notes').delete().eq('id', id);
  }

  // -- CALENDAR EVENTS --
  Future<List<Map<String, dynamic>>> getCalendarEvents() async {
    return client.from('calendar_events').select().order('date', ascending: true);
  }

  Future<void> addCalendarEvent(Map<String, dynamic> event) async {
    await client.from('calendar_events').insert(event);
  }

  Future<void> deleteCalendarEvent(String id) async {
    await client.from('calendar_events').delete().eq('id', id);
  }

  // -- SETTINGS --
  Future<Map<String, dynamic>?> getSettings() async {
    final res = await client.from('user_settings').select().maybeSingle();
    return res;
  }

  Future<void> upsertSettings(Map<String, dynamic> settings) async {
    await client.from('user_settings').upsert(settings, onConflict: 'user_id');
  }
}
