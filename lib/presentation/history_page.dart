import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/stats.dart';
import '../domain/wake_record.dart';
import 'providers.dart';
import 'theme_options.dart';

/// 履歴画面。日ごとの起床時刻・目標時刻・成否・獲得ポイントを
/// 新しい日付順に一覧表示する。
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(recordsProvider);
    final status = Theme.of(context).extension<StatusColors>()!;
    return records.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('読み込みに失敗しました: $e')),
      data: (list) {
        if (list.isEmpty) return const Center(child: Text('まだ記録がありません'));
        return ListView.separated(
          // 先頭はベスト記録のカード、2番目以降が日ごとの記録。
          itemCount: list.length + 1,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            if (i == 0) return _BestRecordsCard(records: list);
            final r = list[i - 1];
            final woke = TimeOfDay.fromDateTime(r.wokeAt).format(context);
            return ListTile(
              key: Key('day_${r.date}'),
              // 成功はチェック、失敗は×で示す(色はテーマに連動)。
              leading: Icon(
                r.success ? Icons.check_circle : Icons.cancel,
                color: r.success ? status.success : status.failure,
              ),
              title: Text(r.date),
              subtitle: Text('起床 $woke / 目標 ${r.targetTime}'),
              trailing: Text('+${r.points} pt'),
            );
          },
        );
      },
    );
  }
}

/// ベスト記録(最長連続成功・最も早い起床・通算成功)のカード。
class _BestRecordsCard extends StatelessWidget {
  const _BestRecordsCard({required this.records});

  /// 集計の対象とする全記録。
  final List<WakeRecord> records;

  /// 時刻を `HH:mm`(24時間表記)にする。
  static String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final streak = longestStreak(records);
    final earliest = earliestWake(records);
    final sum = summary(records);
    return Card(
      key: const Key('best_records_card'),
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Semantics(
              header: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ベスト記録',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
            ),
            _BestRow(
              key: const Key('best_streak'),
              label: '最長連続成功',
              value: streak == null ? '—' : '${streak.days} 日',
              caption: streak == null
                  ? 'まだありません'
                  : '${streak.startDate} 〜 ${streak.endDate}',
            ),
            _BestRow(
              key: const Key('best_earliest'),
              label: '最も早い起床',
              value: earliest == null ? '—' : _hm(earliest.wokeAt),
              caption: earliest == null ? 'まだありません' : earliest.date,
            ),
            _BestRow(
              key: const Key('best_total'),
              label: '通算の成功',
              value: '${sum.successDays} 日',
              caption: '記録 ${sum.recordedDays} 日中・成功率 ${sum.successPercent}%',
            ),
          ],
        ),
      ),
    );
  }
}

/// ベスト記録の1行(項目名・補足・値)。
class _BestRow extends StatelessWidget {
  const _BestRow({
    super.key,
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(label),
    subtitle: Text(caption),
    // 文字が大きくても行の幅を使い切らないよう、最大幅を決めて縮小する。
    trailing: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 120),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(value, style: Theme.of(context).textTheme.titleLarge),
      ),
    ),
  );
}
