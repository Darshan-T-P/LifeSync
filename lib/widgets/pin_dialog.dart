import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PinDialog extends StatefulWidget {
  final String correctPin;
  final String title;
  final String subtitle;

  const PinDialog({
    super.key,
    required this.correctPin,
    this.title = 'Enter PIN',
    this.subtitle = 'Enter your 4-digit PIN to view details',
  });

  static Future<bool> show(BuildContext context, {
    required String correctPin,
    String title = 'Enter PIN',
    String subtitle = 'Enter your 4-digit PIN to view details',
  }) async {
    if (correctPin.isEmpty) return true;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PinDialog(
        correctPin: correctPin,
        title: title,
        subtitle: subtitle,
      ),
    );
    return result ?? false;
  }

  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog> {
  final _code = <int>[];
  bool _error = false;

  void _onDigit(int d) {
    if (_code.length >= 4) return;
    setState(() {
      _code.add(d);
      _error = false;
    });
    if (_code.length == 4) _verify();
  }

  void _onDelete() {
    if (_code.isEmpty) return;
    setState(() {
      _code.removeLast();
      _error = false;
    });
  }

  void _verify() {
    final pin = _code.join();
    if (pin == widget.correctPin) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _error = true;
        _code.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        children: [
          Icon(Icons.lock_outline, size: 32, color: AppTheme.highlight),
          const SizedBox(height: 8),
          Text(widget.title, textAlign: TextAlign.center),
          Text(widget.subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final filled = i < _code.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 14, height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled
                      ? (_error ? AppTheme.warning : AppTheme.highlight)
                      : Colors.grey[200],
                ),
              );
            }),
          ),
          if (_error) ...[
            const SizedBox(height: 8),
            Text('Wrong PIN. Try again.',
              style: TextStyle(fontSize: 11, color: AppTheme.warning)),
          ],
          const SizedBox(height: 20),
          _buildKeypad(),
        ],
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        for (final row in [
          [1, 2, 3],
          [4, 5, 6],
          [7, 8, 9],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((d) => _keyButton(d)).toList(),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 72),
            _keyButton(0),
            GestureDetector(
              onTap: _onDelete,
              child: Container(
                width: 72, height: 56,
                alignment: Alignment.center,
                child: Icon(Icons.backspace_outlined,
                  size: 22, color: Colors.grey[400]),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _keyButton(int digit) {
    return GestureDetector(
      onTap: () => _onDigit(digit),
      child: Container(
        width: 72, height: 56,
        alignment: Alignment.center,
        child: Text('$digit',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
      ),
    );
  }
}
