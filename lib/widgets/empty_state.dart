import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey[500])),
            if (description != null) ...[
              const SizedBox(height: 4),
              Text(description!, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
            ],
          ],
        ),
      ),
    );
  }
}
