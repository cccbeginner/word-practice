import 'package:flutter/material.dart';

class MiniStatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const MiniStatPill({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 380;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 9 : 10,
        vertical: isSmall ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.22),
        ),
      ),
      child: Text(
        '$label：$value',
        style: TextStyle(
          color: color,
          fontSize: isSmall ? 12 : 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
