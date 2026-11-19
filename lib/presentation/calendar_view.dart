import 'package:flutter/material.dart';

import '../domain/calendar.dart';
import '../domain/wake_logic.dart';
import '../domain/wake_record.dart';
import 'theme_options.dart';

/// 曜日の表示名(日曜始まり)。
const List<String> weekdayLabels = ['日', '月', '火', '水', '木', '金', '土'];

/// 日付 [d] の曜日の表示名(「日」〜「土」)。
String weekdayOf(DateTime d) => weekdayLabels[d.weekday % 7];

/// 時刻を `HH:mm`(24時間表記)にする。
String hm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// 月カレンダー。日ごとの成功・失敗を色とアイコンで示し、
/// 日付をタップすると詳細をボトムシートで表示する。
///
/// 文字が極端に大きくなってもマス目が崩れないよう、文字の拡大率は
/// このカレンダー内に限り 1.3 倍までに抑える。
class CalendarView extends StatelessWidget {
  const CalendarView({
    super.key,
    required this.records,
    required this.month,
    required this.range,
    required this.today,
    required this.onMonthChanged,
  });

  /// 全記録。
  final List<WakeRecord> records;

  /// 表示する月(1日の日付)。
  final DateTime month;

  /// 移動できる月の範囲。
  final MonthRange range;

  /// 今日の論理日付 (yyyy-MM-dd)。
  final String today;

  /// 月を移動したときに、移動先の月(1日の日付)で呼ばれる。
  final ValueChanged<DateTime> onMonthChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final byDate = {for (final r in records) r.date: r};
    final grid = monthGrid(month.year, month.month);
    final sum = summaryOfMonth(records, month.year, month.month);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
        child: Column(
          key: const Key('calendar'),
          children: [
            Row(
              children: [
                IconButton(
                  key: const Key('month_prev'),
                  tooltip: '前の月',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: range.canGoPrevious(month)
                      ? () => onMonthChanged(
                          DateTime(month.year, month.month - 1, 1),
                        )
                      : null,
                ),
                Expanded(
                  child: Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text(
                      '${month.year}年${month.month}月',
                      key: const Key('month_title'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('month_next'),
                  tooltip: '次の月',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: range.canGoNext(month)
                      ? () => onMonthChanged(
                          DateTime(month.year, month.month + 1, 1),
                        )
                      : null,
                ),
              ],
            ),
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Center(
                      child: Text(
                        weekdayLabels[i],
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: i == 0
                                  ? scheme.error
                                  : i == 6
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            for (final week in grid)
              Row(
                children: [
                  for (final day in week)
                    Expanded(
                      child: day == null
                          ? const SizedBox(height: 48)
                          : _DayCell(
                              day: day,
                              status: dayStatus(day, byDate, today),
                              isToday: formatDate(day) == today,
                              onTap: () => _showDetail(
                                context,
                                day,
                                byDate[formatDate(day)],
                              ),
                            ),
                    ),
                ],
              ),
            const SizedBox(height: 12),
            Text(
              sum.recorded == 0
                  ? 'この月の記録はありません'
                  : '成功 ${sum.success} 日 / 失敗 ${sum.failure} 日 / 成功率 ${sum.percent}%',
              key: const Key('month_summary'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  /// 日付をタップしたときに、その日の詳細をボトムシートで表示する。
  void _showDetail(BuildContext context, DateTime day, WakeRecord? record) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _DaySheet(day: day, record: record),
    );
  }
}

/// カレンダーの1日分のマス。
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.status,
    required this.isToday,
    required this.onTap,
  });

  final DateTime day;
  final DayStatus status;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = Theme.of(context).extension<StatusColors>()!;
    final isFuture = status == DayStatus.future;

    final Color? background = switch (status) {
      DayStatus.success => colors.success.withValues(alpha: 0.2),
      DayStatus.failure => colors.failure.withValues(alpha: 0.2),
      _ => null,
    };
    final IconData? icon = switch (status) {
      DayStatus.success => Icons.check,
      DayStatus.failure => Icons.close,
      _ => null,
    };
    final Color iconColor = status == DayStatus.success
        ? colors.success
        : colors.failure;
    final statusLabel = switch (status) {
      DayStatus.success => '成功',
      DayStatus.failure => '失敗',
      DayStatus.none => '記録なし',
      DayStatus.future => 'まだ先',
    };

    return Semantics(
      container: true,
      button: !isFuture,
      excludeSemantics: true,
      label: '${day.month}月${day.day}日、$statusLabel${isToday ? '、今日' : ''}',
      onTap: isFuture ? null : onTap,
      child: InkWell(
        key: Key('cell_${formatDate(day)}'),
        onTap: isFuture ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 48,
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
            border: isToday
                ? Border.all(color: scheme.primary, width: 2)
                : null,
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${day.day}',
                  style: TextStyle(
                    color: isFuture
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                    fontWeight: isFuture ? FontWeight.w300 : FontWeight.w500,
                  ),
                ),
                if (icon != null) Icon(icon, size: 14, color: iconColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 日付をタップしたときのボトムシート(その日の詳細)。
class _DaySheet extends StatelessWidget {
  const _DaySheet({required this.day, required this.record});

  final DateTime day;
  final WakeRecord? record;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final colors = Theme.of(context).extension<StatusColors>()!;
    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('day_sheet'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Semantics(
                header: true,
                child: Text(
                  '${day.year}年${day.month}月${day.day}日(${weekdayOf(day)})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            if (r == null)
              const ListTile(title: Text('記録なし'))
            else ...[
              ListTile(
                leading: Icon(
                  r.success ? Icons.check_circle : Icons.cancel,
                  color: r.success ? colors.success : colors.failure,
                ),
                title: Text(r.success ? '成功 +${r.points} pt' : '失敗'),
              ),
              ListTile(title: const Text('起床時刻'), trailing: Text(hm(r.wokeAt))),
              ListTile(
                title: const Text('目標時刻'),
                trailing: Text('${r.targetTime}'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
