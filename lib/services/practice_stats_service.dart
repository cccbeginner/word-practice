import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_constants.dart';
import '../models/word_stats.dart';

class PracticeStatsService {
  Future<Map<int, WordStats>> loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(statsStorageKey);

    if (raw == null || raw.trim().isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;

      return decoded.map((key, value) {
        return MapEntry(
          int.parse(key),
          WordStats.fromJson(Map<String, dynamic>.from(value as Map)),
        );
      });
    } catch (_) {
      await prefs.remove(statsStorageKey);
      return {};
    }
  }

  Future<void> saveStats(Map<int, WordStats> statsByWordId) async {
    final prefs = await SharedPreferences.getInstance();

    final data = statsByWordId.map((wordId, stats) {
      return MapEntry(wordId.toString(), stats.toJson());
    });

    await prefs.setString(statsStorageKey, jsonEncode(data));
  }

  Future<void> clearStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(statsStorageKey);
  }
}
