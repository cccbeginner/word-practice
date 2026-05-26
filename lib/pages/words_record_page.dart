import 'package:flutter/material.dart';

import '../models/word_item.dart';
import '../models/word_stats.dart';
import '../widgets/word_record_card.dart';

class WordsRecordPage extends StatefulWidget {
  final List<WordItem> words;
  final Map<int, WordStats> statsByWordId;
  final Future<void> Function() onClearRecords;

  const WordsRecordPage({
    super.key,
    required this.words,
    required this.statsByWordId,
    required this.onClearRecords,
  });

  @override
  State<WordsRecordPage> createState() => _WordsRecordPageState();
}

class _WordsRecordPageState extends State<WordsRecordPage> {
  late Map<int, WordStats> _statsByWordId;

  @override
  void initState() {
    super.initState();
    _statsByWordId = Map<int, WordStats>.from(widget.statsByWordId);
  }

  Future<void> _clearRecords() async {
    await widget.onClearRecords();

    if (!mounted) return;

    setState(() {
      _statsByWordId = {};
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('所有單字紀錄已清空。'),
      ),
    );
  }

  Color _statusColor(WordStats stats) {
    if (stats.correct == 0 && stats.wrong == 0) {
      return Colors.grey;
    }

    if (stats.wrong > stats.correct) {
      return Colors.red;
    }

    if (stats.correct == stats.wrong) {
      return Colors.amber;
    }

    return Colors.green;
  }

  int _statusSortRank(WordStats stats) {
    if (stats.wrong > stats.correct) {
      return 0;
    }

    if (stats.correct == stats.wrong && stats.total > 0) {
      return 1;
    }

    if (stats.total == 0) {
      return 2;
    }

    return 3;
  }

  @override
  Widget build(BuildContext context) {
    final words = [...widget.words]..sort((a, b) {
        final statsA = _statsByWordId[a.id] ?? const WordStats();
        final statsB = _statsByWordId[b.id] ?? const WordStats();

        final rankA = _statusSortRank(statsA);
        final rankB = _statusSortRank(statsB);

        if (rankA != rankB) {
          return rankA.compareTo(rankB);
        }

        return a.id.compareTo(b.id);
      });

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('單字紀錄'),
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
                  children: [
                    Card(
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
                              '單字紀錄總覽',
                              style: TextStyle(
                                fontSize: isMobile ? 18 : 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '排序：答錯較多在最上面，接著是一樣多、尚未作答，答對較多放最下面。',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: isMobile ? 13 : 14,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: _clearRecords,
                                icon: const Icon(Icons.delete_outline_rounded),
                                label: const Text('清空所有紀錄'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: isMobile ? 8 : 12),
                    ...words.map((word) {
                      final stats = _statsByWordId[word.id] ?? const WordStats();
                      final color = _statusColor(stats);

                      return Padding(
                        padding: EdgeInsets.only(bottom: isMobile ? 8 : 10),
                        child: WordRecordCard(
                          word: word,
                          stats: stats,
                          color: color,
                        ),
                      );
                    }),
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
