import '../core/supabase_client.dart';
import '../models/word_item.dart';

class WordRepository {
  Future<List<WordItem>> loadActiveWords() async {
    final rows = await supabase
        .from('words')
        .select('id, chinese, english')
        .eq('is_active', true)
        .order('id', ascending: true);

    return (rows as List)
        .map(
          (row) => WordItem.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }
}
