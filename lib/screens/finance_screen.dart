import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../supabase/client.dart';
import '../models/transaction.dart';
import '../models/settings.dart';
import '../models/bank_account.dart';
import '../models/savings_pot.dart';
import '../theme/app_theme.dart';
import '../theme/app_settings.dart';
import '../widgets/empty_state.dart';
import '../widgets/modal_sheet.dart';
import '../widgets/pin_dialog.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final _supabase = SupabaseService.instance;
  List<Transaction> _transactions = [];
  List<BankAccount> _banks = [];
  List<SavingsPot> _savingsPots = [];
  UserSettings? _settings;
  bool _loading = true;
  bool _showLimits = false;
  String _activeTab = 'overview';

  // Add form
  String _type = 'expense';
  final _amountCtrl = TextEditingController();
  String _cat = 'Food';
  String _source = 'cash';
  String? _sourceBankId;
  final _noteCtrl = TextEditingController();
  String _date = '';

  @override
  void initState() {
    super.initState();
    _date = _today();
    _load();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  bool _isUnlocked = false;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final settingsRaw = await _supabase.getSettings();
      if (settingsRaw != null) _settings = UserSettings.fromMap(settingsRaw);

      final pin = _settings?.pin ?? '';
      if (pin.isNotEmpty && !_isUnlocked) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final authed = await PinDialog.show(context, correctPin: pin,
            title: 'Finance Data',
            subtitle: 'Enter PIN to view your finances',
          );
          if (authed == true) {
            _isUnlocked = true;
            _fetchData();
          } else {
            if (mounted) Navigator.pop(context);
          }
        });
        return;
      }

      await _fetchData();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchData() async {
    try {
      final userId = _supabase.client.auth.currentUser?.id;
      if (userId != null) {
        await _supabase.ensureSource(userId, 'cash', 'Cash');
      }
      final raw = await _supabase.getTransactions();
      final banksRaw = await _supabase.getBanks();
      final potsRaw = await _supabase.getSavingsPots();
      if (mounted) {
        setState(() {
          _transactions = raw.map((e) => Transaction.fromMap(e)).toList();
          _banks = banksRaw.map((e) => BankAccount.fromMap(e)).toList()
            ..removeWhere((b) => b.sourceType == 'gmoney');
          _savingsPots = potsRaw.map((e) => SavingsPot.fromMap(e)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _monthStr() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  List<Transaction> get _monthly =>
      _transactions.where((t) => t.date.startsWith(_monthStr())).toList();

  // Get total money across all sources (from banks table balances)
  double get _totalMoney => _banks.fold<double>(0, (s, b) => s + b.balance);

  // Cash balance from banks table
  double get _cashBalance {
    final cash = _banks.where((b) => b.sourceType == 'cash').firstOrNull;
    return cash?.balance ?? 0;
  }

  // All bank-type accounts
  List<BankAccount> get _bankAccounts => _banks.where((b) => b.sourceType == 'bank').toList();

  // Total bank money
  double get _totalBankMoney => _bankAccounts.fold<double>(0, (s, b) => s + b.balance);

  Map<String, double> _expensesBySource(List<Transaction> txns) {
    final map = <String, double>{};
    for (final t in txns.where((t) => t.type == 'expense')) {
      final key = t.sourceId ?? t.source;
      map[key] = (map[key] ?? 0) + t.amount;
    }
    return map;
  }

  Color _sourceColor(String key) {
    final src = _banks.where((b) => b.id == key).firstOrNull;
    if (src != null) {
      if (src.sourceType == 'cash') return AppTheme.highlight;
      return const Color(0xFF06B6D4);
    }
    return Colors.grey;
  }

  Future<void> _addEntry() async {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (amount <= 0) return;
    final userId = _supabase.client.auth.currentUser?.id;
    if (userId == null) return;

    final sourceId = _sourceBankId;
    final source = _banks.where((b) => b.id == sourceId).firstOrNull;
    final sourceType = source?.sourceType ?? 'cash';

    final txn = Transaction(
      id: const Uuid().v4(),
      userId: userId,
      type: _type,
      amount: amount,
      category: _cat,
      source: sourceType,
      sourceId: sourceId,
      note: _noteCtrl.text.trim(),
      date: _date,
    );
    await _supabase.addTransaction(txn.toMap());

    // Update source balance
    if (sourceId != null) {
      final balanceChange = _type == 'income' ? amount : -amount;
      await _supabase.updateBank(sourceId, {
        'balance': (source?.balance ?? 0) + balanceChange,
      });
    }

    _amountCtrl.clear();
    _noteCtrl.clear();
    _type = 'expense';
    _cat = 'Food';
    _source = 'cash';
    final cash = _banks.where((b) => b.sourceType == 'cash').firstOrNull;
    _sourceBankId = cash?.id;
    _date = _today();
    if (!mounted) return;
    Navigator.pop(context);
    _load();
  }

  Future<void> _delete(String id) async {
    final txn = _transactions.where((t) => t.id == id).firstOrNull;
    if (txn != null && txn.sourceId != null) {
      final source = _banks.where((b) => b.id == txn.sourceId).firstOrNull;
      if (source != null) {
        final balanceChange = txn.type == 'income' ? -txn.amount : txn.amount;
        await _supabase.updateBank(txn.sourceId!, {
          'balance': (source.balance) + balanceChange,
        });
      }
    }
    await _supabase.deleteTransaction(id);
    _load();
  }

  Future<void> _saveBudgetLimit(String cat, double limit) async {
    final limits = Map<String, double>.from(_settings?.budgetLimits ?? {});
    limits[cat] = limit;
    final userId = _supabase.client.auth.currentUser?.id;
    if (userId == null) return;
    final updated = _settings?.copyWith(budgetLimits: limits) ?? UserSettings(
      userId: userId,
      budgetLimits: limits,
    );
    await _supabase.upsertSettings(updated.toMap());
    _load();
  }

  Future<void> _addSavingsPot(String name, double target) async {
    final userId = _supabase.client.auth.currentUser?.id;
    if (userId == null) return;
    final pot = SavingsPot(
      id: const Uuid().v4(), userId: userId,
      name: name, targetAmount: target,
    );
    await _supabase.addSavingsPot(pot.toMap());
    _load();
  }

  Future<void> _updateSavingsPot(SavingsPot pot, double addAmount) async {
    final updated = pot.copyWith(savedAmount: pot.savedAmount + addAmount);
    if (pot.id != null) {
      await _supabase.updateSavingsPot(pot.id!, updated.toMap());
      _load();
    }
  }

  Future<void> _deleteSavingsPot(String id) async {
    await _supabase.deleteSavingsPot(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final monthly = _monthly;
    final totalIn = monthly.where((t) => t.type == 'income').fold<double>(0, (s, t) => s + t.amount);
    final totalOut = monthly.where((t) => t.type == 'expense').fold<double>(0, (s, t) => s + t.amount);
    final net = totalIn - totalOut;
    final sips = _settings?.sips ?? [];
    final totalSip = sips.fold<double>(0, (s, sip) => s + sip.amount);

    final catSpending = <String, double>{};
    for (final f in monthly.where((t) => t.type == 'expense')) {
      catSpending[f.category] = (catSpending[f.category] ?? 0) + f.amount;
    }
    final chartData = financeCategories
        .map((c) => _ChartData(c, catSpending[c] ?? 0))
        .where((d) => d.amount > 0)
        .toList();

    final allSourceExpenses = _expensesBySource(monthly);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppSettings.translate('finance'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _showLimits = !_showLimits),
                      child: Text(AppSettings.translate('budgets'),
                        style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                    ),
                    FilledButton.icon(
                      onPressed: () => _showAddSheet(),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(AppSettings.translate('add'),
                        style: const TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Total Money Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOTAL MONEY',
                    style: TextStyle(fontSize: 9, letterSpacing: 1.2,
                        color: Colors.grey[400], fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Text('${AppTheme.rupee}${_fmt(_totalMoney)}',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                        color: Colors.white)),
                  const SizedBox(height: 12),
                  // Breakdown row
                  Row(
                    children: [
                      _moneyBreakdownChip(Icons.money, 'Cash',
                          _cashBalance, AppTheme.highlight),
                      const SizedBox(width: 10),
                      _moneyBreakdownChip(Icons.account_balance, 'Banks',
                          _totalBankMoney, const Color(0xFF06B6D4)),
                    ],
                  ),
                  // Individual bank balances
                  if (_bankAccounts.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 10),
                    for (final bank in _bankAccounts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.circle, size: 6,
                                color: Color(0xFF06B6D4)),
                            const SizedBox(width: 8),
                            Text(bank.name, style: const TextStyle(
                                fontSize: 12, color: Colors.white70)),
                            const Spacer(),
                            Text('${AppTheme.rupee}${_fmt(bank.balance)}',
                              style: const TextStyle(fontSize: 12,
                                  color: Colors.white, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Monthly Flow
            Row(
              children: [
                _summaryCard('Income',
                    '+${AppTheme.rupee}${_fmt(totalIn)}', AppTheme.success),
                const SizedBox(width: 8),
                _summaryCard('Spent',
                    '-${AppTheme.rupee}${_fmt(totalOut)}', AppTheme.warning),
                const SizedBox(width: 8),
                _summaryCard('Net',
                    '${net >= 0 ? '+' : ''}${AppTheme.rupee}${_fmt(net)}',
                    net >= 0 ? AppTheme.success : AppTheme.warning),
              ],
            ),
            const SizedBox(height: 12),

            // Tab bar for sections
            Row(
              children: [
                _tabBtn('overview', 'Overview'),
                _tabBtn('sources', 'Sources'),
                _tabBtn('savings', 'Savings'),
              ],
            ),
            const SizedBox(height: 12),

            if (_activeTab == 'overview') ...[
              // Simplified Chart
              if (chartData.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: _cardDec(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SPENDING',
                        style: TextStyle(fontSize: 9, letterSpacing: 1,
                            color: Colors.grey[400], fontWeight: FontWeight.w500)),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 160,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: chartData.map((d) => d.amount)
                                .reduce((a, b) => a > b ? a : b) * 1.3,
                            barTouchData: BarTouchData(
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  return BarTooltipItem(
                                    '${AppTheme.rupee}${_fmt(rod.toY)}',
                                    const TextStyle(color: Colors.white, fontSize: 11),
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final idx = value.toInt();
                                    if (idx < 0 || idx >= chartData.length) {
                                      return const SizedBox();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        chartData[idx].category.substring(0, 3),
                                        style: TextStyle(fontSize: 9,
                                            color: Colors.grey[500]),
                                      ),
                                    );
                                  },
                                  reservedSize: 22,
                                ),
                              ),
                              leftTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              topTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval:
                                  chartData.map((d) => d.amount)
                                      .reduce((a, b) => a > b ? a : b) / 4,
                              getDrawingHorizontalLine: (value) =>
                                  FlLine(color: Colors.grey[100]!,
                                      strokeWidth: 1),
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: chartData.asMap().entries.map((e) =>
                              BarChartGroupData(
                                x: e.key,
                                barRods: [
                                  BarChartRodData(
                                    toY: e.value.amount,
                                    color: AppTheme.chartColors[
                                        e.key % AppTheme.chartColors.length],
                                    width: 20,
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(4)),
                                  )
                                ],
                              ),
                            ).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // SIPs
              if (sips.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: _cardDec(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SIP INVESTMENTS',
                        style: TextStyle(fontSize: 9, letterSpacing: 1,
                            color: Colors.grey[400], fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      for (final s in sips)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(s.name,
                                  style: const TextStyle(fontSize: 13)),
                              Text('${AppTheme.rupee}${_fmt(s.amount)}/mo',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total SIP',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          Text('${AppTheme.rupee}${_fmt(totalSip)}/mo',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Budget Limits
              if (_showLimits) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: _cardDec(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppSettings.translate('budget_limits'),
                        style: TextStyle(fontSize: 9, letterSpacing: 1,
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      for (final c in financeCategories)
                        _budgetLimitRow(c, catSpending),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Recent transactions
              Text(AppSettings.translate('recent_transactions'),
                style: TextStyle(fontSize: 9, letterSpacing: 1,
                    color: Colors.grey[400], fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              if (monthly.isEmpty)
                const EmptyState(
                    icon: Icons.account_balance_wallet,
                    title: 'No transactions yet',
                    description: 'Add your first income or expense')
              else
                for (final t in monthly.take(20))
                  _transactionTile(t),
            ],

            if (_activeTab == 'sources') ...[
              for (final src in _banks) ...[
                if (src.sourceType == 'cash')
                  _sourceCard(
                    icon: Icons.money,
                    label: src.name,
                    balance: src.balance,
                    expenses: allSourceExpenses[src.id] ?? 0,
                    color: AppTheme.highlight,
                  )
                else if (src.sourceType == 'bank')
                  _bankCard(src, allSourceExpenses),
                const SizedBox(height: 8),
              ],

              if (_banks.where((b) => b.sourceType == 'bank').isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: _cardDec(),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.account_balance,
                            size: 32, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text('No bank accounts added',
                          style: TextStyle(fontSize: 13,
                              color: Colors.grey[400])),
                        const SizedBox(height: 4),
                        Text('Add banks in Settings',
                          style: TextStyle(fontSize: 10,
                              color: Colors.grey[400])),
                      ],
                    ),
                  ),
                ),
            ],

            if (_activeTab == 'savings') ...[
              ..._savingsPots.map((pot) => _savingsPotCard(pot)),
              const SizedBox(height: 8),
              if (_savingsPots.isEmpty)
                const EmptyState(
                    icon: Icons.savings_outlined,
                    title: 'No savings pots',
                    description: 'Create a savings pot with a target amount')
              else
                const SizedBox(height: 4),
              FilledButton.icon(
                onPressed: _showAddPotSheet,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Savings Pot',
                    style: TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.highlight,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tabBtn(String tab, String label) {
    final active = _activeTab == tab;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = tab),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: active ? AppTheme.highlight : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? AppTheme.highlight : Colors.grey[200]!,
            ),
          ),
          child: Text(label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: active ? Colors.white : Colors.grey[500],
            )),
        ),
      ),
    );
  }

  Widget _sourceCard({
    required IconData icon,
    required String label,
    required double balance,
    required double expenses,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _cardDec(),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
                Text('${AppTheme.rupee}${_fmt(balance)} balance',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[400])),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${AppTheme.rupee}${_fmt(expenses)} spent',
                style: TextStyle(
                    fontSize: 11, color: AppTheme.warning)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bankCard(BankAccount bank, Map<String, double> expenses) {
    final key = bank.id ?? bank.name;
    final exp = expenses[key] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _cardDec(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance,
                    size: 18, color: Color(0xFF06B6D4)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bank.name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                    Text('${AppTheme.rupee}${_fmt(bank.balance)} balance',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[400])),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _showBankDetails(bank),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.highlight.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Details',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.highlight,
                      fontWeight: FontWeight.w500,
                    )),
                ),
              ),
            ],
          ),
          if (exp > 0) ...[
            const SizedBox(height: 6),
            Text('${AppTheme.rupee}${_fmt(exp)} spent this month',
              style: TextStyle(fontSize: 11, color: Colors.grey[400])),
          ],
        ],
      ),
    );
  }

  Future<void> _showBankDetails(BankAccount bank) async {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text(bank.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _detailRow('Account', bank.accountNumber.isNotEmpty
                ? bank.accountNumber : 'N/A'),
            const SizedBox(height: 8),
            _detailRow('Balance',
                '${AppTheme.rupee}${_fmt(bank.balance)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        Text(value,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _savingsPotCard(SavingsPot pot) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: _cardDec(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.highlight.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.savings_outlined,
                    size: 18, color: AppTheme.highlight),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pot.name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                    Text(
                      '${AppTheme.rupee}${_fmt(pot.savedAmount)} / ${AppTheme.rupee}${_fmt(pot.targetAmount)}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _showAddToPotSheet(pot),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.highlight.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Add',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.highlight,
                      fontWeight: FontWeight.w500,
                    )),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _confirmDeletePot(pot),
                child: Icon(Icons.close,
                    size: 14, color: Colors.grey[300]),
              ),
            ],
          ),
          if (pot.targetAmount > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pot.progress / 100,
                backgroundColor: Colors.grey[100],
                valueColor: AlwaysStoppedAnimation(
                  pot.progress >= 100
                      ? AppTheme.success
                      : AppTheme.highlight,
                ),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Text('${pot.progress.toStringAsFixed(0)}% complete',
              style: TextStyle(
                  fontSize: 9, color: Colors.grey[400])),
          ],
        ],
      ),
    );
  }

  void _confirmDeletePot(SavingsPot pot) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete pot?'),
        content: Text('Delete "${pot.name}"? This won\'t affect transactions.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (pot.id != null) _deleteSavingsPot(pot.id!);
              Navigator.pop(context);
            },
            child: Text('Delete',
                style: TextStyle(color: AppTheme.warning)),
          ),
        ],
      ),
    );
  }

  void _showAddToPotSheet(SavingsPot pot) {
    final ctrl = TextEditingController();
    AppModalSheet.show(context, 'Add to ${pot.name}', StatefulBuilder(
      builder: (context, setSheetState) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Amount (${AppTheme.rupee})',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[200]!)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final amt = double.tryParse(ctrl.text) ?? 0;
                if (amt > 0) {
                  _updateSavingsPot(pot, amt);
                  Navigator.pop(context);
                }
              },
              style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.highlight),
              child: const Text('Add'),
            ),
          ),
        ],
      ),
    ));
  }

  void _showAddPotSheet() {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    AppModalSheet.show(context, 'New Savings Pot', StatefulBuilder(
      builder: (context, setSheetState) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Pot name (e.g. Emergency Fund)',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[200]!)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: targetCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Target amount (${AppTheme.rupee})',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[200]!)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final target = double.tryParse(targetCtrl.text) ?? 0;
                if (name.isNotEmpty) {
                  _addSavingsPot(name, target);
                  Navigator.pop(context);
                }
              },
              style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.highlight),
              child: const Text('Create Pot'),
            ),
          ),
        ],
      ),
    ));
  }

  Widget _moneyBreakdownChip(IconData icon, String label, double amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 9, color: color)),
                  Text('${AppTheme.rupee}${_fmt(amount)}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(
      String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _cardDec(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 9, color: Colors.grey[400])),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: color)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _budgetLimitRow(
      String cat, Map<String, double> catSpending) {
    final limit = _settings?.budgetLimits[cat] ?? 0;
    final spent = catSpending[cat] ?? 0;
    final exceeded = limit > 0 && spent > limit;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 80,
              child: Text(cat,
                  style: const TextStyle(fontSize: 13))),
          SizedBox(
            width: 72,
            child: TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: AppTheme.rupee,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide:
                        BorderSide(color: Colors.grey[200]!)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 12),
              controller: TextEditingController(
                  text: limit > 0 ? limit.toStringAsFixed(0) : ''),
              onSubmitted: (v) => _saveBudgetLimit(
                  cat, double.tryParse(v) ?? 0),
            ),
          ),
          const Spacer(),
          Text('${AppTheme.rupee}${_fmt(spent)}',
            style: TextStyle(
              fontSize: 12,
              color: exceeded
                  ? AppTheme.warning
                  : Colors.grey[400],
              fontWeight: exceeded
                  ? FontWeight.w600
                  : FontWeight.normal,
            )),
          if (exceeded)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.warning_amber_rounded,
                  size: 12, color: AppTheme.warning),
            ),
        ],
      ),
    );
  }

  Widget _transactionTile(Transaction t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: _cardDec(),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: (t.type == 'income'
                      ? AppTheme.success
                      : AppTheme.warning)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              t.type == 'income'
                  ? Icons.trending_up
                  : Icons.trending_down,
              size: 16,
              color: t.type == 'income'
                  ? AppTheme.success
                  : AppTheme.warning,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${t.category}${t.note.isNotEmpty ? ' — ${t.note}' : ''}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Text(
                      DateFormat('d MMM')
                          .format(DateTime.parse(t.date)),
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey[400]),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: _sourceColor(t.source)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        sourceLabels[t.source] ?? t.source,
                        style: TextStyle(
                          fontSize: 8,
                          color: _sourceColor(t.source),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${t.type == 'income' ? '+' : '-'}${AppTheme.rupee}${_fmt(t.amount)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: t.type == 'income'
                  ? AppTheme.success
                  : AppTheme.warning,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _delete(t.id),
            child: Icon(Icons.close,
                size: 14, color: Colors.grey[300]),
          ),
        ],
      ),
    );
  }

  void _showAddSheet() {
    _amountCtrl.clear();
    _noteCtrl.clear();
    _type = 'expense';
    _cat = 'Food';
    _source = 'cash';
    final cash = _banks.where((b) => b.sourceType == 'cash').firstOrNull;
    _sourceBankId = cash?.id;
    _date = _today();

    AppModalSheet.show(context, 'Add Entry', StatefulBuilder(
      builder: (context, setSheetState) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Type toggle
          Row(
            children: [
              Expanded(
                child: _typeBtn('Expense', 'expense',
                    AppTheme.warning, setSheetState),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _typeBtn('Income', 'income',
                    AppTheme.success, setSheetState),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Amount
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Amount (${AppTheme.rupee})',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: Colors.grey[200]!)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),

          // Category
          DropdownButtonFormField<String>(
            key: ValueKey('cat_$_type'),
            initialValue: _cat,
            decoration: _fieldDec(),
            items: (_type == 'expense'
                    ? financeCategories
                    : incomeCategories)
                .map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c,
                        style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: (v) =>
                setSheetState(() => _cat = v!),
          ),
          const SizedBox(height: 12),

          // Source — where is the money coming from / going to?
          DropdownButtonFormField<String>(
            key: ValueKey('src_$_type'),
            initialValue: _type == 'income' && _source == 'parents' ? 'parents' : _sourceBankId,
            decoration: _fieldDec(),
            items: [
              for (final s in _banks)
                DropdownMenuItem(
                    value: s.id,
                    child: Row(
                      children: [
                        Icon(
                          s.sourceType == 'cash' ? Icons.money :
                          Icons.account_balance,
                          size: 14, color: s.sourceType == 'cash'
                              ? AppTheme.highlight : const Color(0xFF06B6D4),
                        ),
                        const SizedBox(width: 6),
                        Text(s.name,
                            style: const TextStyle(fontSize: 13)),
                      ],
                    )),
              if (_type == 'income')
                const DropdownMenuItem(
                    value: 'parents',
                    child: Text('Parents')),
            ],
            onChanged: (v) => setSheetState(() {
              if (v == 'parents') {
                _source = 'parents';
                _sourceBankId = null;
              } else {
                final src = _banks.firstWhere((b) => b.id == v);
                _source = src.sourceType;
                _sourceBankId = src.id;
              }
            }),
          ),
          const SizedBox(height: 12),

          // Note
          TextField(
            controller: _noteCtrl,
            decoration: InputDecoration(
              hintText: 'Note (optional)',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: Colors.grey[200]!)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),

          // Submit
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _addEntry,
              style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary),
              child: Text(
                  'Add ${_type == 'expense' ? 'Expense' : 'Income'}'),
            ),
          ),
        ],
      ),
    ));
  }

  Widget _typeBtn(String label, String value, Color color,
      StateSetter setSheetState) {
    final active = _type == value;
    return GestureDetector(
      onTap: () => setSheetState(() {
        _type = value;
        _cat = value == 'expense' ? 'Food' : 'Salary';
        if (value == 'expense') {
          final cash = _banks.where((b) => b.sourceType == 'cash').firstOrNull;
          if (cash != null) {
            _source = 'cash';
            _sourceBankId = cash.id;
          }
        } else {
          _source = 'parents';
          _sourceBankId = null;
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active ? color : Colors.grey[200]!),
        ),
        child: Center(
          child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: active ? Colors.white : Colors.grey[500],
            )),
        ),
      ),
    );
  }

  InputDecoration _fieldDec() => InputDecoration(
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[200]!)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 10),
        isDense: true,
      );

  BoxDecoration _cardDec() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[100]!),
      );

  String _fmt(double v) => v.toStringAsFixed(0);
}

class _ChartData {
  final String category;
  final double amount;
  _ChartData(this.category, this.amount);
}
