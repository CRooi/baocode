import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:bao_agent/bao_agent.dart';
import 'package:bao_remote/local.dart';
import 'package:path/path.dart' as p;

import 'claude_compaction.dart';

Future<CompactionSource?> readCompactionSource(String sessionId) async {
  if (!RegExp(r'^[0-9a-zA-Z][0-9a-zA-Z_-]*$').hasMatch(sessionId)) {
    return null;
  }
  final config = await ClaudeEnvironment.configDir();
  if (config.isEmpty) return null;
  return Isolate.run(() {
    final path = AgentPaths(home: '', configDir: config).findSession(sessionId);
    if (path == null) return null;
    final store = SessionStore.resume(
      sessionId: sessionId,
      cwd: '',
      file: path,
      persist: false,
    );
    final messages = store.apiMessages();
    if (messages.isEmpty) return null;
    return (path: path, messages: messages);
  });
}

Future<void> writeCompaction(
  String path, {
  required String summary,
  required bool auto,
  int? preTokens,
  int? postTokens,
  Duration? duration,
}) async {
  final file = File(path);
  final store = SessionStore.resume(
    sessionId: p.basenameWithoutExtension(path),
    cwd: '',
    file: path,
    persist: false,
  );
  final last = store.chain.lastOrNull;
  if (last == null) throw StateError('Nothing to compact in $path.');
  final now = DateTime.now().toUtc().toIso8601String();
  final shared = <String, Object?>{
    'userType': last['userType'] ?? 'external',
    if (last['entrypoint'] case final Object entrypoint)
      'entrypoint': entrypoint,
    'cwd': last['cwd'],
    'sessionId': last['sessionId'] ?? p.basenameWithoutExtension(path),
    if (last['version'] case final Object version) 'version': version,
    if (last['gitBranch'] case final Object branch) 'gitBranch': branch,
  };
  final boundary = newUuid();
  final lines = [
    {
      'parentUuid': null,
      'logicalParentUuid': last['uuid'],
      'isSidechain': false,
      'type': 'system',
      'subtype': 'compact_boundary',
      'content': 'Conversation compacted',
      'level': 'info',
      'compactMetadata': {
        'trigger': auto ? 'auto' : 'manual',
        'preTokens': ?preTokens,
        'postTokens': ?postTokens,
        'durationMs': ?duration?.inMilliseconds,
      },
      'uuid': boundary,
      'timestamp': now,
      ...shared,
    },
    {
      'parentUuid': boundary,
      'isSidechain': false,
      'type': 'user',
      'message': {
        'role': 'user',
        'content': compactedSummary(summary, transcriptPath: path),
      },
      'isVisibleInTranscriptOnly': true,
      'isCompactSummary': true,
      'uuid': newUuid(),
      'timestamp': now,
      ...shared,
    },
  ];
  // The file may not end in a newline (a line cut short).
  final length = await file.length();
  var lead = '';
  if (length > 0) {
    final handle = await file.open();
    try {
      await handle.setPosition(length - 1);
      if ((await handle.read(1)).firstOrNull != 0x0a) lead = '\n';
    } finally {
      await handle.close();
    }
  }
  await file.writeAsString(
    '$lead${lines.map(jsonEncode).join('\n')}\n',
    mode: FileMode.append,
    flush: true,
  );
}
