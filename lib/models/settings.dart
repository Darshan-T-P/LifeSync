import 'dart:convert';
import 'bank_account.dart';
import 'savings_pot.dart';

class UserSettings {
  final String? id;
  final String userId;
  final String name;
  final double monthlyBudget;
  final String pin;
  final bool notifyBudgetExceeded;
  final bool notifyDailySummary;
  final bool notifyWeeklyReport;
  final Map<String, double> budgetLimits;
  final List<SipEntry> sips;
  final List<SavingsPot> savingsPots;
  final List<BankAccount> banks;

  UserSettings({
    this.id,
    required this.userId,
    this.name = '',
    this.monthlyBudget = 0,
    this.pin = '',
    this.notifyBudgetExceeded = true,
    this.notifyDailySummary = false,
    this.notifyWeeklyReport = false,
    Map<String, double>? budgetLimits,
    List<SipEntry>? sips,
    List<SavingsPot>? savingsPots,
    List<BankAccount>? banks,
  }) : budgetLimits = budgetLimits ?? {},
       sips = sips ?? [],
       savingsPots = savingsPots ?? [],
       banks = banks ?? [];

  factory UserSettings.fromMap(Map<String, dynamic> map) {
    List<SipEntry> sips = [];
    if (map['sips'] != null) {
      final raw = map['sips'] is String ? jsonDecode(map['sips']) : map['sips'];
      sips = (raw as List<dynamic>).map((e) => SipEntry.fromMap(e)).toList();
    }
    Map<String, double> limits = {};
    if (map['budget_limits'] != null) {
      final raw = map['budget_limits'] is String ? jsonDecode(map['budget_limits']) : map['budget_limits'];
      (raw as Map<String, dynamic>).forEach((k, v) => limits[k] = (v as num).toDouble());
    }
    List<SavingsPot> pots = [];
    if (map['savings_pots'] != null) {
      final raw = map['savings_pots'] is String ? jsonDecode(map['savings_pots']) : map['savings_pots'];
      pots = (raw as List<dynamic>).map((e) => SavingsPot.fromMap(e)).toList();
    }
    List<BankAccount> banks = [];
    if (map['banks'] != null) {
      final raw = map['banks'] is String ? jsonDecode(map['banks']) : map['banks'];
      banks = (raw as List<dynamic>).map((e) => BankAccount.fromMap(e)).toList();
    }
    return UserSettings(
      id: map['id'] as String?,
      userId: map['user_id'] as String,
      name: (map['name'] as String?) ?? '',
      monthlyBudget: ((map['monthly_budget'] as num?) ?? 0).toDouble(),
      pin: (map['pin'] as String?) ?? '',
      notifyBudgetExceeded: (map['notify_budget_exceeded'] as bool?) ?? true,
      notifyDailySummary: (map['notify_daily_summary'] as bool?) ?? false,
      notifyWeeklyReport: (map['notify_weekly_report'] as bool?) ?? false,
      budgetLimits: limits,
      sips: sips,
      savingsPots: pots,
      banks: banks,
    );
  }

  Map<String, dynamic> toMap() => {
    if (id != null && id!.isNotEmpty) 'id': id,
    'user_id': userId,
    'name': name,
    'monthly_budget': monthlyBudget,
    'pin': pin,
    'notify_budget_exceeded': notifyBudgetExceeded,
    'notify_daily_summary': notifyDailySummary,
    'notify_weekly_report': notifyWeeklyReport,
    'budget_limits': budgetLimits,
    'sips': sips.map((e) => e.toMap()).toList(),
  };

  UserSettings copyWith({
    String? name,
    double? monthlyBudget,
    String? pin,
    bool? notifyBudgetExceeded,
    bool? notifyDailySummary,
    bool? notifyWeeklyReport,
    Map<String, double>? budgetLimits,
    List<SipEntry>? sips,
    List<SavingsPot>? savingsPots,
    List<BankAccount>? banks,
  }) => UserSettings(
    id: id, userId: userId,
    name: name ?? this.name,
    monthlyBudget: monthlyBudget ?? this.monthlyBudget,
    pin: pin ?? this.pin,
    notifyBudgetExceeded: notifyBudgetExceeded ?? this.notifyBudgetExceeded,
    notifyDailySummary: notifyDailySummary ?? this.notifyDailySummary,
    notifyWeeklyReport: notifyWeeklyReport ?? this.notifyWeeklyReport,
    budgetLimits: budgetLimits ?? this.budgetLimits,
    sips: sips ?? this.sips,
    savingsPots: savingsPots ?? this.savingsPots,
    banks: banks ?? this.banks,
  );
}

class SipEntry {
  final String name;
  final double amount;

  SipEntry({required this.name, required this.amount});

  factory SipEntry.fromMap(Map<String, dynamic> map) {
    return SipEntry(
      name: map['name'] as String,
      amount: (map['amount'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'amount': amount};
}
