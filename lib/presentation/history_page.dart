import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/achievements.dart';
import '../domain/calendar.dart';
import '../domain/stats.dart';
import '../domain/wake_record.dart';
import 'calendar_view.dart';
import 'providers.dart';
import 'theme_options.dart';

/// 履歴画面。ベスト記録、バッジ、日ごとの履歴(カレンダー/リスト)を表示する。
///
/// 日ごとの履歴は、月カレンダー(初期表示)と、新しい日付順のリストを切り替えられる。
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  /// カレンダー表示か(`false` ならリスト表示)。
  bool _calendar = true;

  /// カレンダーで表示中の月(1日の日付)。`null` なら今日の月。
  DateTime? _month;

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(recordsProvider);
    final today = ref.watch(todayProvider);
    final status = Theme.of(context).extension<StatusColors>()!;
    return records.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('読み込みに失敗しました: $e')),
      data: (list) {
        if (list.isEmpty) return const Center(child: Text('まだ記録がありません'));
        final range = monthRange(list, today);
        final month = range.clamp(_month ?? range.last);
        return ListView.separated(
          // 先頭から、ベスト記録・バッジ・表示切替。その下が日ごとの履歴
          // (カレンダーは1項目、リストは1日1項目)。
          itemCount: 3 + (_calendar ? 1 : list.length),
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            if (i == 0) return _BestRecordsCard(records: list);
            if (i == 1) return _BadgesCard(records: list);
            if (i == 2) {
              return _ViewToggle(
                calendar: _calendar,
                onChanged: (v) => setState(() => _calendar = v),
              );
            }
            if (_calendar) {
              return CalendarView(
                records: list,
                month: month,
                range: range,
                today: today,
                onMonthChanged: (m) => setState(() => _month = m),
              );
            }
            final r = list[i - 3];
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

/// 「カレンダー / リスト」の表示切替。文字が大きくても折り返せるよう `Wrap` で並べる。
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.calendar, required this.onChanged});

  /// カレンダー表示中か。
  final bool calendar;

  /// 切り替えたときに、カレンダー表示にするか(`true`)リストにするか(`false`)で呼ばれる。
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          key: const Key('view_calendar'),
          label: const Text('カレンダー'),
          avatar: const Icon(Icons.calendar_month, size: 18),
          selected: calendar,
          onSelected: (_) => onChanged(true),
        ),
        ChoiceChip(
          key: const Key('view_list'),
          label: const Text('リスト'),
          avatar: const Icon(Icons.list, size: 18),
          selected: !calendar,
          onSelected: (_) => onChanged(false),
        ),
      ],
    ),
  );
}

/// ベスト記録(最長連続成功・最も早い起床・通算成功)のカード。
class _BestRecordsCard extends StatelessWidget {
  const _BestRecordsCard({required this.records});

  /// 集計の対象とする全記録。
  final List<WakeRecord> records;

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
              container: true,
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
              value: earliest == null ? '—' : hm(earliest.wokeAt),
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

/// 連続成功のバッジ一覧(取得済みは色付き、未取得は灰色)。
class _BadgesCard extends StatelessWidget {
  const _BadgesCard({required this.records});

  /// 取得状況を調べる全記録。
  final List<WakeRecord> records;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final badges = badgeStatuses(records);
    final earnedCount = badges.where((b) => b.earned).length;
    return Card(
      key: const Key('badges_card'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              container: true,
              header: true,
              child: Text(
                'バッジ($earnedCount/${badges.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '連続して成功した日数で手に入ります',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final b in badges)
                  Semantics(
                    key: Key('badge_${b.days}'),
                    // カードに統合されず、バッジごとに個別に読み上げられるようにする。
                    container: true,
                    label: '${b.days}日連続のバッジ、${b.earned ? '取得済み' : '未取得'}',
                    excludeSemantics: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          b.earned ? Icons.emoji_events : Icons.lock_outline,
                          size: 36,
                          color: b.earned
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                        Text(
                          '${b.days}日',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
