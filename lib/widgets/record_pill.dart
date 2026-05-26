import 'package:flutter/material.dart';

class RecordPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const RecordPill({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isVerySmall = MediaQuery.of(context).size.width < 380;

    return Container(
      constraints: const BoxConstraints(minWidth: 48),
      padding: EdgeInsets.symmetric(
        horizontal: isVerySmall ? 7 : 8,
        vertical: isVerySmall ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        '$label $value',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: isVerySmall ? 11 : 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
