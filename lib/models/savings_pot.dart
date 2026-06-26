class SavingsPot {
  final String? id;
  final String userId;
  final String name;
  final double targetAmount;
  final double savedAmount;

  SavingsPot({
    this.id,
    required this.userId,
    required this.name,
    this.targetAmount = 0,
    this.savedAmount = 0,
  });

  double get progress => targetAmount > 0 ? (savedAmount / targetAmount * 100).clamp(0, 100) : 0;
  double get remaining => (targetAmount - savedAmount).clamp(0, double.infinity);

  factory SavingsPot.fromMap(Map<String, dynamic> map) {
    return SavingsPot(
      id: map['id'] as String?,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      targetAmount: ((map['target_amount'] as num?) ?? 0).toDouble(),
      savedAmount: ((map['saved_amount'] as num?) ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    if (id != null && id!.isNotEmpty) 'id': id,
    'user_id': userId,
    'name': name,
    'target_amount': targetAmount,
    'saved_amount': savedAmount,
  };

  SavingsPot copyWith({
    String? name,
    double? targetAmount,
    double? savedAmount,
  }) => SavingsPot(
    id: id,
    userId: userId,
    name: name ?? this.name,
    targetAmount: targetAmount ?? this.targetAmount,
    savedAmount: savedAmount ?? this.savedAmount,
  );
}
