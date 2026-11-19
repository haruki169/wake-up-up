import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/record_repository.dart';
import '../data/settings_repository.dart';
import '../domain/wake_logic.dart';
import '../domain/wake_record.dart';

/// 現在時刻の取得元。テストで固定時刻に差し替えられるようにしている。
final clockProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// 起床記録の保存先。`main` またはテストで必ず override する。
final recordRepositoryProvider = Provider<RecordRepository>(
  (_) => throw UnimplementedError(),
);

/// 設定の保存先。`main` またはテストで必ず override する。
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (_) => throw UnimplementedError(),
);

/// 目標起床時刻の状態管理。変更すると保存先にも書き込む。
class TargetTimeNotifier extends Notifier<TargetTime> {
  @override
  TargetTime build() => ref.read(settingsRepositoryProvider).targetTime;

  /// 目標時刻を [t] に変更して保存する。
  Future<void> set(TargetTime t) async {
    await ref.read(settingsRepositoryProvider).setTargetTime(t);
    state = t;
  }
}

/// 現在の目標起床時刻。
final targetTimeProvider = NotifierProvider<TargetTimeNotifier, TargetTime>(
  TargetTimeNotifier.new,
);

/// 起床記録一覧(新しい日付順)の状態管理。
class RecordsNotifier extends AsyncNotifier<List<WakeRecord>> {
  @override
  Future<List<WakeRecord>> build() => ref.read(recordRepositoryProvider).all();

  /// 「起きた」ボタンの処理。現在時刻で記録を作って保存し、一覧を更新する。
  ///
  /// 今日(論理日付)が記録済みの場合、保存はされず一覧は変わらない。
  Future<void> wake() async {
    final now = ref.read(clockProvider)();
    final repo = ref.read(recordRepositoryProvider);
    final record = buildRecord(now, ref.read(targetTimeProvider));
    await repo.insert(record);
    state = AsyncData(await repo.all());
  }
}

/// 起床記録の一覧。ホームの集計と履歴画面が共有する。
final recordsProvider =
    AsyncNotifierProvider<RecordsNotifier, List<WakeRecord>>(
      RecordsNotifier.new,
    );

/// 今日の論理日付 (yyyy-MM-dd) の状態管理。
///
/// 次の日付の境界(午前3:00)になると自動で再計算して状態を更新するため、
/// アプリを開いたままでも画面が翌日の表示に切り替わる。
class TodayNotifier extends Notifier<String> {
  @override
  String build() {
    final now = ref.read(clockProvider)();
    // 次の境界の時刻に、自分自身を作り直して日付を更新する。
    final timer = Timer(
      nextDayBoundary(now).difference(now),
      ref.invalidateSelf,
    );
    ref.onDispose(timer.cancel);
    return logicalDate(now);
  }
}

/// 今日の論理日付。ホームの「今日の記録」の判定に使う。
final todayProvider = NotifierProvider<TodayNotifier, String>(
  TodayNotifier.new,
);
