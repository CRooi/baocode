import 'claude_compaction.dart';

Future<CompactionSource?> readCompactionSource(String sessionId) async => null;

Future<void> writeCompaction(
  String path, {
  required String summary,
  required bool auto,
  int? preTokens,
  int? postTokens,
  Duration? duration,
}) async => throw UnsupportedError('Not available on the web.');
