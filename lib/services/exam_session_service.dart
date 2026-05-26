import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_constants.dart';
import '../models/exam_models.dart';

class ExamSessionService {
  Future<ExamSession?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(examSessionStorageKey);

    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      return ExamSession.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      await prefs.remove(examSessionStorageKey);
      return null;
    }
  }

  Future<void> saveSession(ExamSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(examSessionStorageKey, jsonEncode(session.toJson()));
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(examSessionStorageKey);
  }
}
