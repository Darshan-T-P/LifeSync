import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../theme/app_settings.dart';
import '../supabase/client.dart';
import '../models/settings.dart';
import '../models/bank_account.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _supabase = SupabaseService.instance;
  final _nameCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  bool _loading = true;
  bool _pinVisible = false;
  UserSettings? _settings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _budgetCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final raw = await _supabase.getSettings();
      UserSettings? loadedSettings;
      if (raw != null) {
        loadedSettings = UserSettings.fromMap(raw);
      } else {
        final currentUser = _supabase.client.auth.currentUser;
        final userId = currentUser?.id ?? const Uuid().v4();
        loadedSettings = UserSettings(userId: userId);
      }
      
      final banksRaw = await _supabase.getBanks();
      final banksList = banksRaw.map((e) => BankAccount.fromMap(e)).toList();
      _settings = loadedSettings.copyWith(banks: banksList);

      _nameCtrl.text = _settings?.name ?? '';
      _budgetCtrl.text = _settings?.monthlyBudget.toString() ?? '0';
      _pinCtrl.text = _settings?.pin ?? '';
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    final budget = double.tryParse(_budgetCtrl.text.trim()) ?? 0;
    final pin = _pinCtrl.text.trim();
    if (_settings != null) {
      final updated = _settings!.copyWith(
        name: name,
        monthlyBudget: budget,
        pin: pin.isNotEmpty ? pin : _settings!.pin,
      );
      await _supabase.upsertSettings(updated.toMap());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
    }
  }

  Future<void> _saveNotificationPrefs({
    bool? notifyBudgetExceeded,
    bool? notifyDailySummary,
    bool? notifyWeeklyReport,
  }) async {
    if (_settings == null) return;
    final updated = _settings!.copyWith(
      notifyBudgetExceeded: notifyBudgetExceeded ?? _settings!.notifyBudgetExceeded,
      notifyDailySummary: notifyDailySummary ?? _settings!.notifyDailySummary,
      notifyWeeklyReport: notifyWeeklyReport ?? _settings!.notifyWeeklyReport,
    );
    _settings = updated;
    await _supabase.upsertSettings(updated.toMap());
    setState(() {});
  }

  Future<void> _addBank() async {
    final nameCtrl = TextEditingController();
    final acctCtrl = TextEditingController();
    final balCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Account (Bank/Cash)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Account Name (e.g. HDFC, Hand Cash)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: acctCtrl,
              decoration: const InputDecoration(
                labelText: 'Account Number (optional)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: balCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Current Balance',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) Navigator.pop(context, true);
            },
            child: const Text('Add Account'),
          ),
        ],
      ),
    );
    if (result != true) return;
    final userId = _supabase.client.auth.currentUser?.id;
    if (userId == null) return;
    final bank = BankAccount(
      id: const Uuid().v4(),
      userId: userId,
      name: nameCtrl.text.trim(),
      accountNumber: acctCtrl.text.trim(),
      balance: double.tryParse(balCtrl.text.trim()) ?? 0,
    );
    await _supabase.addBank(bank.toMap());
    _load();
  }

  Future<void> _deleteBank(BankAccount bank) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Bank?'),
        content: Text('Remove "${bank.name}"? Transactions linked to it won\'t be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove', style: TextStyle(color: AppTheme.warning)),
          ),
        ],
      ),
    );
    if (confirm == true && bank.id != null) {
      await _supabase.deleteBank(bank.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppSettings.translate;

    return Scaffold(
      backgroundColor: AppTheme.neutral,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(t('settings'), style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Branding
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1a1a1a), Color(0xFF2a2a2a)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.highlight.withValues(alpha: 0.4), width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.highlight.withValues(alpha: 0.3),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('LifeSync',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
                        const SizedBox(height: 4),
                        Text('v1.0.0 • Personal Life Dashboard',
                          style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Profile
                  _sectionHeader(t('user_profile')),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[100]!),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(
                            labelText: 'Display Name',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _budgetCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Monthly Budget Limit (${AppTheme.rupee})',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_settings?.pin.isNotEmpty == true)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.lock, size: 20, color: Colors.grey),
                                SizedBox(width: 12),
                                Text('PIN is Set (Private)', style: TextStyle(fontWeight: FontWeight.w500)),
                              ],
                            ),
                          )
                        else
                          TextField(
                            controller: _pinCtrl,
                            obscureText: !_pinVisible,
                            maxLength: 4,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Finance PIN (4-digit)',
                              hintText: 'Set a PIN to protect your finances',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              suffixIcon: IconButton(
                                icon: Icon(_pinVisible ? Icons.visibility_off : Icons.visibility, size: 18),
                                onPressed: () => setState(() => _pinVisible = !_pinVisible),
                              ),
                              counterText: '',
                            ),
                          ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _saveProfile,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(t('save_settings')),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sources Section (Cash, gMoney, Banks)
                  _sectionHeader('SOURCES'),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[100]!),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text('All sources (Cash, gMoney, Banks)',
                                style: TextStyle(fontSize: 9, letterSpacing: 1,
                                  color: Colors.grey, fontWeight: FontWeight.w500)),
                            ),
                            GestureDetector(
                              onTap: _addBank,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.highlight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add, size: 12, color: Colors.white),
                                    SizedBox(width: 2),
                                    Text('Add Bank', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if ((_settings?.banks ?? []).isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text('No sources added',
                              style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                          )
                        else
                          for (final src in (_settings?.banks ?? []))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32, height: 32,
                                    decoration: BoxDecoration(
                                      color: (src.sourceType == 'cash'
                                          ? AppTheme.highlight
                                          : const Color(0xFF06B6D4)).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      src.sourceType == 'cash' ? Icons.money :
                                      Icons.account_balance,
                                      size: 16,
                                      color: src.sourceType == 'cash'
                                          ? AppTheme.highlight
                                          : const Color(0xFF06B6D4),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(src.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                        if (src.accountNumber.isNotEmpty)
                                          Text('****${src.accountNumber.length > 4 ? src.accountNumber.substring(src.accountNumber.length - 4) : src.accountNumber}',
                                            style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: TextField(
                                      controller: TextEditingController(
                                        text: src.balance.toStringAsFixed(0)),
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      style: const TextStyle(fontSize: 12),
                                      onSubmitted: (v) {
                                        final bal = double.tryParse(v) ?? 0;
                                        if (src.id != null) {
                                          _supabase.updateBank(src.id!, {'balance': bal});
                                        }
                                      },
                                    ),
                                  ),
                                  if (src.isBank) ...[
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () => _deleteBank(src),
                                      child: Icon(Icons.close, size: 14, color: Colors.grey[300]),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Notifications Section
                  _sectionHeader('NOTIFICATIONS'),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[100]!),
                    ),
                    child: Column(
                      children: [
                        _toggleTile(
                          'Budget Exceeded Alert',
                          'Notify when spending exceeds monthly budget',
                          _settings?.notifyBudgetExceeded ?? true,
                          (v) => _saveNotificationPrefs(notifyBudgetExceeded: v),
                        ),
                        const Divider(height: 4),
                        _toggleTile(
                          'Daily Summary',
                          'Send a daily spending summary',
                          _settings?.notifyDailySummary ?? false,
                          (v) => _saveNotificationPrefs(notifyDailySummary: v),
                        ),
                        const Divider(height: 4),
                        _toggleTile(
                          'Weekly Report',
                          'Send a weekly finance report every Monday',
                          _settings?.notifyWeeklyReport ?? false,
                          (v) => _saveNotificationPrefs(notifyWeeklyReport: v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Preferences
                  _sectionHeader(t('preferences')),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[100]!),
                    ),
                    child: Column(
                      children: [
                        _dropdownSetting(
                          label: t('font_style'),
                          value: AppSettings.instance.fontStyle.value,
                          items: AppSettings.fonts,
                          onChanged: (val) {
                            if (val != null) {
                              AppSettings.instance.fontStyle.value = val;
                              setState(() {});
                            }
                          },
                        ),
                        const Divider(height: 24),
                        _dropdownSetting(
                          label: t('language_label'),
                          value: AppSettings.instance.language.value,
                          items: AppSettings.languages,
                          onChanged: (val) {
                            if (val != null) {
                              AppSettings.instance.language.value = val;
                              setState(() {});
                            }
                          },
                        ),
                        const Divider(height: 24),
                        _dropdownSetting(
                          label: t('currency_label'),
                          value: AppSettings.instance.currency.value,
                          items: AppSettings.currencies,
                          onChanged: (val) {
                            if (val != null) {
                              AppSettings.instance.currency.value = val;
                              setState(() {});
                            }
                          },
                        ),
                        const Divider(height: 24),
                        _dropdownSetting(
                          label: t('system_units'),
                          value: AppSettings.instance.metricSystem.value,
                          items: AppSettings.metrics,
                          onChanged: (val) {
                            if (val != null) {
                              AppSettings.instance.metricSystem.value = val;
                              setState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _toggleTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey[400])),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.highlight,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: AppTheme.highlight,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _dropdownSetting({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primary)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              items: items.map((e) {
                return DropdownMenuItem(
                  value: e,
                  child: Text(e, style: const TextStyle(fontSize: 13, color: AppTheme.primary)),
                );
              }).toList(),
              onChanged: onChanged,
              icon: const Icon(Icons.keyboard_arrow_down, size: 18),
              style: const TextStyle(color: AppTheme.primary),
            ),
          ),
        ),
      ],
    );
  }
}
