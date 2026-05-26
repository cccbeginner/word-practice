import 'package:flutter/material.dart';

import '../models/exam_models.dart';
import '../utils/date_format.dart';
import '../widgets/score_chip.dart';

class ExamRecordPage extends StatelessWidget {
  final ExamSession session;

  const ExamRecordPage({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('考試紀錄'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 12 : 20,
            12,
            isMobile ? 12 : 20,
            24,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ExamSummaryCard(session: session),
                    SizedBox(height: isMobile ? 10 : 14),
                    if (session.answers.isEmpty)
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(isMobile ? 16 : 20),
                          child: const Text(
                            '目前還沒有答題紀錄。開始作答後，每一題的答案會自動存進 SharedPreferences。',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      ...session.answers.map((record) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: isMobile ? 8 : 10),
                          child: _ExamRecordCard(record: record),
                        );
                      }),
                    if (!session.completed && session.remainingCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '未作答：${session.remainingCount} 題。為避免洩漏考題，尚未作答的單字不會在紀錄頁顯示答案。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: isMobile ? 12 : 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamSummaryCard extends StatelessWidget {
  final ExamSession session;

  const _ExamSummaryCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isVerySmall = MediaQuery.of(context).size.width < 380;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 18 : 22),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 14 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.completed ? '考試結果' : '考試進度',
              style: TextStyle(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '開始：${formatDateTime(session.startedAt)}\n'
              '結束：${formatDateTime(session.finishedAt)}',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: isMobile ? 13 : 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
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
                  label: '已答',
                  value: '${session.answeredCount}/${session.totalQuestions}',
                  color: Colors.blue,
                ),
                ScoreChip(
                  label: '答對',
                  value: session.correctCount.toString(),
                  color: Colors.green,
                ),
                ScoreChip(
                  label: '答錯',
                  value: session.wrongCount.toString(),
                  color: Colors.red,
                ),
                ScoreChip(
                  label: '正確率',
                  value: '${session.accuracy}%',
                  color: Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamRecordCard extends StatelessWidget {
  final ExamAnswerRecord record;

  const _ExamRecordCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final color = record.isCorrect ? Colors.green : Colors.red;
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
          vertical: isVerySmall ? 10 : 12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: isVerySmall ? 15 : 17,
              backgroundColor: color.withValues(alpha: 0.14),
              child: Text(
                record.questionNumber.toString(),
                style: TextStyle(
                  color: color,
                  fontSize: isVerySmall ? 12 : 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.chinese,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isVerySmall ? 16 : 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '你的答案：${record.userAnswer}',
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontSize: isVerySmall ? 13 : 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '正確答案：${record.correctEnglish}',
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontSize: isVerySmall ? 13 : 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '作答時間：${formatDateTime(record.answeredAt)}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: isVerySmall ? 11 : 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              record.isCorrect
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}
