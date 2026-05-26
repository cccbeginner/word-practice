import 'package:flutter/material.dart';

import '../models/word_item.dart';
import '../models/word_stats.dart';
import 'record_pill.dart';

class WordRecordCard extends StatelessWidget {
  final WordItem word;
  final WordStats stats;
  final Color color;

  const WordRecordCard({
    super.key,
    required this.word,
    required this.stats,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isVerySmall = MediaQuery.of(context).size.width < 380;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isVerySmall ? 10 : 12,
          vertical: isVerySmall ? 8 : 10,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.chinese,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isVerySmall ? 16 : 17,
                      fontWeight: FontWeight.bold,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    word.english,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontSize: isVerySmall ? 13 : 14,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                RecordPill(
                  label: '對',
                  value: stats.correct.toString(),
                  color: Colors.green,
                ),
                const SizedBox(height: 4),
                RecordPill(
                  label: '錯',
                  value: stats.wrong.toString(),
                  color: Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
