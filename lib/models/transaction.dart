class Transaction {
  final String id;
  final String userId;
  final String type; // income / expense
  final double amount;
  final String category;
  final String source; // cash / bank / savings / parents / other
  final String? sourceId; // bank_account id if source is 'bank'
  final String note;
  final String date;
  final String createdAt;

  Transaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.category,
    this.source = 'cash',
    this.sourceId,
    this.note = '',
    String? date,
    String? createdAt,
  }) : date = date ?? _today(),
       createdAt = createdAt ?? _today();

  static String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      source: (map['source'] as String?) ?? 'cash',
      sourceId: map['source_id'] as String?,
      note: (map['note'] as String?) ?? '',
      date: map['date'] as String?,
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    if (id.isNotEmpty) 'id': id,
    'user_id': userId,
    'type': type,
    'amount': amount,
    'category': category,
    if (sourceId != null) 'source_id': sourceId,
    'note': note,
    'date': date,
    'created_at': createdAt,
  };
}

const List<String> financeCategories = [
  'Food', 'Transport', 'College', 'Subscriptions',
  'Entertainment', 'Savings', 'Investment', 'Other',
];

const List<String> incomeCategories = [
  'Salary', 'Freelance', 'Parents', 'Investment', 'Gift', 'Other',
];

const List<String> expenseSources = [
  'cash', 'bank',
];

const Map<String, String> sourceLabels = {
  'cash': 'Cash',
  'bank': 'Bank',
  'savings': 'Savings Pot',
  'parents': 'Parents',
  'other': 'Other',
};
