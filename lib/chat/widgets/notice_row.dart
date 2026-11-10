import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/model_provider.dart' show formatTokens;
import '../../theme/app_theme.dart';
import '../../theme/workbench_theme.dart' show themeColors;
import '../chat_display_settings.dart';
import '../chat_models.dart';
import 'agent_step.dart';
import 'markdown_view.dart';

/// A line from the runtime rather than the agent: a compaction divider, a
/// retry or error, a hint, or the output of a command run in the session.
class NoticeRow extends StatelessWidget {
  const NoticeRow({super.key, required this.item});

  final NoticeItem item;

  @override
  Widget build(BuildContext context) {
    final text = item.text;
    switch (item.kind) {
      case NoticeKind.compaction:
        final compaction = item.compaction;
        final l10n = context.l10n;
        final parts = compaction == null
            ? [text]
            : [
                compaction.auto ? l10n.chatCompactedAuto : l10n.chatCompacted,
                if (compaction.before case final before?)
                  [
                    formatTokens(before),
                    if (compaction.after case final after?) formatTokens(after),
                  ].join(' → '),
                ?compaction.model,
                if (compaction.duration case final duration?)
                  AgentStep.formatDuration(duration, l10n: l10n),
                if (compaction.tokensPerSecond case final speed?)
                  l10n.turnSpeed(speed.toStringAsFixed(2)),
                if (compaction.tokens case final tokens? when tokens > 0)
                  l10n.turnTokens(AgentStep.formatTokens(tokens, decimals: 2)),
              ];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                Expanded(child: Divider(color: AppColors.partBorder)),
                const SizedBox(width: 10),
                Icon(
                  Icons.compress_rounded,
                  size: 13,
                  color: AppColors.textFaint,
                ),
                const SizedBox(width: 6),
                // One line, as wide as it needs: the lines take the rest.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: math.max(0, constraints.maxWidth - 120),
                  ),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        for (final (i, part) in parts.indexed) ...[
                          if (i > 0)
                            const WidgetSpan(child: SizedBox(width: 10)),
                          TextSpan(text: part),
                        ],
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textFaint,
                      fontSize: ChatFontSize.scaled(12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Divider(color: AppColors.partBorder)),
              ],
            ),
          ),
        );
      case NoticeKind.command:
        return Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.partBorder),
          ),
          child: MarkdownView(
            text,
            style: MarkdownView.baseStyle.copyWith(
              fontSize: ChatFontSize.scaled(13),
            ),
          ),
        );
      case NoticeKind.retry ||
          NoticeKind.error ||
          NoticeKind.info ||
          NoticeKind.warning:
        final error = themeColors['errorForeground'];
        final (icon, color) = switch (item.kind) {
          NoticeKind.error => (Icons.error_outline_rounded, error),
          NoticeKind.warning || NoticeKind.retry => (
            Icons.warning_amber_rounded,
            themeColors['notificationsWarningIcon.foreground'],
          ),
          _ => (Icons.info_outline_rounded, AppColors.textMuted),
        };
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: item.kind == NoticeKind.error
                        ? error
                        : AppColors.textMuted,
                    fontSize: ChatFontSize.scaled(12.5),
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }
}
