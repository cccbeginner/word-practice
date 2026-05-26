import 'package:flutter/material.dart';

import 'score_chip.dart';

class PracticeScoreCard extends StatelessWidget {
  final int correctCount;
  final int wrongCount;
  final int total;
  final int accuracy;
  final VoidCallback onClear;
  final VoidCallback onOpenRecords;

  const PracticeScoreCard({
    super.key,
    required this.correctCount,
    required this.wrongCount,
    required this.total,
    required this.accuracy,
    required this.onClear,
    required this.onOpenRecords,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final isVerySmall = constraints.maxWidth < 380;

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isMobile ? 18 : 22),
          ),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 18),
            child: Column(
              children: [
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: isMobile ? 2 : 4,
                  mainAxisSpacing: isMobile ? 10 : 12,
                  crossAxisSpacing: isMobile ? 10 : 12,
                  childAspectRatio: isVerySmall
                      ? 1.9
                      : isMobile
                          ? 2.15
                          : 1.75,
                  children: [
                    ScoreChip(
                      label: '答對',
                      value: correctCount.toString(),
                      color: Colors.green,
                    ),
                    ScoreChip(
                      label: '答錯',
                      value: wrongCount.toString(),
                      color: Colors.red,
                    ),
                    ScoreChip(
                      label: '總答題',
                      value: total.toString(),
                      color: Colors.blue,
                    ),
                    ScoreChip(
                      label: '正確率',
                      value: '$accuracy%',
                      color: Colors.purple,
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 10 : 14),
                if (isMobile)
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: FilledButton.icon(
                          onPressed: onOpenRecords,
                          icon: const Icon(Icons.list_alt_rounded, size: 18),
                          label: const Text('查看單字紀錄'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: OutlinedButton.icon(
                          onPressed: onClear,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('清空紀錄'),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 180,
                        height: 44,
                        child: FilledButton.icon(
                          onPressed: onOpenRecords,
                          icon: const Icon(Icons.list_alt_rounded, size: 18),
                          label: const Text('查看紀錄'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 180,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: onClear,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('清空紀錄'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
