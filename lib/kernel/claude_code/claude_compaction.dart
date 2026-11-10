// A conversation of Claude Code's compacted by a model of the user's
// picking (Settings → Models): BaoCode asks it for the summary, and writes
// it in the session's file as Claude Code writes its own, for the CLI to
// go on from when it resumes the session.

import 'dart:convert';

import 'package:bao_agent/bao_agent.dart' show compactPrompt;

import '../output_meter.dart';
import 'claude_compaction_stub.dart'
    if (dart.library.io) 'claude_compaction_io.dart'
    as platform;

/// The session's conversation since its last compaction, as the Messages
/// API takes it, and where its file is; null when the file is not found.
typedef CompactionSource = ({String path, List<Map<String, Object?>> messages});

/// [sessionId]'s file under Claude Code's folder and its conversation
/// since its last compaction; null where it is not there.
Future<CompactionSource?> readCompactionSource(String sessionId) =>
    platform.readCompactionSource(sessionId);

/// Ends [path]'s conversation with a compaction: its boundary, then
/// [summary] as the message the conversation goes on from, as Claude Code
/// writes its own. Resumed, the CLI sends the model only what follows.
Future<void> writeCompaction(
  String path, {
  required String summary,
  required bool auto,
  int? preTokens,
  int? postTokens,
  Duration? duration,
}) => platform.writeCompaction(
  path,
  summary: summary,
  auto: auto,
  preTokens: preTokens,
  postTokens: postTokens,
  duration: duration,
);

/// What the model that sums the conversation up is told it is.
const compactionSystem =
    'You write the summary of a conversation between a user and a coding '
    'agent, for the work to go on from.';

/// The one message the model writes the summary of [transcript] (see
/// [compactionTranscript]) for.
List<Map<String, Object?>> compactionMessages(String transcript) => [
  {
    'role': 'user',
    'content':
        '<conversation>\n$transcript</conversation>\n\n${compactPrompt()}',
  },
];

/// [messages] (as the Messages API takes them) written out as one text, a
/// part a message: for any model to read, whatever it speaks, without the
/// tools and thoughts each upstream takes otherwise. Tool results longer
/// than [resultLimit] characters are cut short, those of the oldest first,
/// until the whole comes to [budget] tokens (or every one is cut).
String compactionTranscript(
  List<Map<String, Object?>> messages, {
  int? budget,
  int resultLimit = 2000,
}) {
  final results = <({int message, int block})>[];
  for (final (i, message) in messages.indexed) {
    if (message['content'] case final List<Object?> blocks) {
      for (final (j, block) in blocks.indexed) {
        if (block case {'type': 'tool_result'}) {
          results.add((message: i, block: j));
        }
      }
    }
  }
  final cut = <({int message, int block})>{};
  var text = _render(messages, cut, resultLimit);
  if (budget == null) return text;
  // The oldest results cut first, a batch at a time, until it fits.
  var next = 0;
  while (OutputMeter.estimateTokens(text) > budget && next < results.length) {
    final batch = (results.length / 10).ceil().clamp(1, results.length);
    cut.addAll(results.skip(next).take(batch));
    next += batch;
    text = _render(messages, cut, resultLimit);
  }
  return text;
}

String _render(
  List<Map<String, Object?>> messages,
  Set<({int message, int block})> cut,
  int resultLimit,
) {
  final out = StringBuffer();
  for (final (i, message) in messages.indexed) {
    final role = message['role'] == 'assistant' ? 'Assistant' : 'User';
    final parts = <String>[];
    switch (message['content']) {
      case final String text:
        parts.add(text);
      case final List<Object?> blocks:
        for (final (j, block) in blocks.indexed) {
          if (block is! Map) continue;
          switch (block['type']) {
            case 'text':
              parts.add('${block['text'] ?? ''}');
            case 'tool_use':
              parts.add(
                '[Tool call ${block['name']}: ${jsonEncode(block['input'])}]',
              );
            case 'tool_result':
              var result = _resultText(block['content']);
              if (cut.contains((message: i, block: j)) &&
                  result.length > resultLimit) {
                result =
                    '${result.substring(0, resultLimit)}\n[… '
                    '${result.length - resultLimit} more characters]';
              }
              parts.add(
                '[Tool result${block['is_error'] == true ? ' (error)' : ''}: '
                '$result]',
              );
            case 'image':
              parts.add('[Image]');
            case 'document':
              parts.add('[Document]');
          }
        }
    }
    final text = parts.where((part) => part.trim().isNotEmpty).join('\n');
    if (text.isEmpty) continue;
    out
      ..writeln('<$role>')
      ..writeln(text)
      ..writeln('</$role>')
      ..writeln();
  }
  return out.toString();
}

String _resultText(Object? content) => switch (content) {
  final String text => text,
  final List<Object?> blocks => [
    for (final block in blocks)
      if (block case {'type': 'text', 'text': final String text})
        text
      else if (block case {'type': 'image'})
        '[Image]',
  ].join('\n'),
  _ => '',
};
