class BankAccount {
  final String? id;
  final String userId;
  final String name;
  final String accountNumber;
  final double balance;
  final String sourceType; // 'cash' or 'bank'

  BankAccount({
    this.id,
    required this.userId,
    required this.name,
    required this.accountNumber,
    this.balance = 0,
    this.sourceType = 'bank',
  });

  bool get isBank => sourceType == 'bank';

  factory BankAccount.fromMap(Map<String, dynamic> map) {
    final st = map['source_type'] as String?;
    return BankAccount(
      id: map['id'] as String?,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      accountNumber: (map['account_number'] as String?) ?? '',
      balance: ((map['balance'] as num?) ?? 0).toDouble(),
      sourceType: st ?? 'bank',
    );
  }

  Map<String, dynamic> toMap() => {
    if (id != null && id!.isNotEmpty) 'id': id,
    'user_id': userId,
    'name': name,
    'account_number': accountNumber,
    'balance': balance,
    'source_type': sourceType,
  };

  BankAccount copyWith({
    String? name,
    String? accountNumber,
    double? balance,
    String? sourceType,
  }) => BankAccount(
    id: id,
    userId: userId,
    name: name ?? this.name,
    accountNumber: accountNumber ?? this.accountNumber,
    balance: balance ?? this.balance,
    sourceType: sourceType ?? this.sourceType,
  );
}
