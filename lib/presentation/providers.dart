import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/record_repository.dart';
import '../data/reward_repository.dart';
import '../data/settings_repository.dart';
import '../domain/achievements.dart';
import '../domain/app_settings.dart';
import '../domain/reward.dart';
import '../domain/wake_logic.dart';
import '../domain/wake_record.dart';

/// 現在時刻の取得元。テストで固定時刻に差し替えられるようにしている。
final clockProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// 起床記録の保存先。`main` またはテストで必ず override する。
final recordRepositoryProvider = Provider<RecordRepository>(
  (_) => throw UnimplementedError(),
);

/// ご褒美・交換・残高の保存先。`main` またはテストで override する。
final rewardRepositoryProvider = Provider<RewardRepository>(
  (_) => throw UnimplementedError(),
);

/// 設定の保存先。`main` またはテストで必ず override する。
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (_) => throw UnimplementedError(),
);

/// アプリ設定の状態管理。変更すると保存先にも書き込む。
class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(settingsRepositoryProvider).load();

  /// [change] で設定を変更して保存する。
  ///
  /// 例: `update((s) => s.copyWith(themeColorIndex: 3))`
  Future<void> update(AppSettings Function(AppSettings current) change) async {
    final next = change(state);
    await ref.read(settingsRepositoryProvider).save(next);
    state = next;
  }

  /// 目標起床時刻を [t] に変更する。過去の記録には影響しない。
  Future<void> setTargetTime(TargetTime t) =>
      update((s) => s.copyWith(targetTime: t));
}

/// アプリ設定。
final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

/// 現在の目標起床時刻(設定から取り出した値)。
final targetTimeProvider = Provider<TargetTime>(
  (ref) => ref.watch(settingsProvider.select((s) => s.targetTime)),
);

/// 「起きた」を押した結果。
class WakeResult {
  const WakeResult({required this.saved, required this.achievements});

  /// 記録が新しく保存されたか(今日が記録済みなら `false`)。
  final bool saved;

  /// 達成した内容(保存されなかったときは何もない)。
  final Achievements achievements;
}

/// 起床記録一覧(新しい日付順)の状態管理。
class RecordsNotifier extends AsyncNotifier<List<WakeRecord>> {
  @override
  Future<List<WakeRecord>> build() => ref.read(recordRepositoryProvider).all();

  /// 「起きた」ボタンの処理。現在時刻で記録を作って保存し、一覧を更新する。
  ///
  /// 今日(論理日付)が記録済みの場合、保存はされず一覧は変わらない。
  /// 戻り値には、保存できたかどうかと、節目などの達成内容が入る。
  Future<WakeResult> wake() async {
    final now = ref.read(clockProvider)();
    final repo = ref.read(recordRepositoryProvider);
    final before = state.value ?? await repo.all();
    final record = buildRecord(now, ref.read(targetTimeProvider));
    final saved = await repo.insert(record);
    state = AsyncData(await repo.all());
    return WakeResult(
      saved: saved,
      achievements: saved
          ? detectAchievements(before, record)
          : const Achievements(),
    );
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

/// ご褒美画面の状態(ご褒美・交換履歴・ポイント)。
class RewardsState {
  const RewardsState({
    required this.rewards,
    required this.redemptions,
    required this.earned,
    required this.spent,
  });

  /// アーカイブしていないご褒美(登録順)。
  final List<Reward> rewards;

  /// 交換履歴(新しい順)。
  final List<Redemption> redemptions;

  /// 累計獲得ポイント。
  final int earned;

  /// 使用済みポイント。
  final int spent;

  /// ポイント残高(累計獲得 − 使用済み)。
  int get balance => pointBalance(earned: earned, spent: spent);
}

/// ご褒美・交換・残高の状態管理。
///
/// 起床記録が変わる(新しく記録する)と、獲得ポイントが変わるため再計算する。
class RewardsNotifier extends AsyncNotifier<RewardsState> {
  @override
  Future<RewardsState> build() {
    // 記録が更新されたら、累計獲得・残高を作り直す。
    ref.watch(recordsProvider);
    return _load();
  }

  Future<RewardsState> _load() async {
    final repo = ref.read(rewardRepositoryProvider);
    return RewardsState(
      rewards: await repo.activeRewards(),
      redemptions: await repo.redemptions(),
      earned: await repo.totalEarned(),
      spent: await repo.totalSpent(),
    );
  }

  /// 成功したときだけ状態を読み込み直して、結果をそのまま返す。
  Future<RewardResult> _reloadIfOk(Future<RewardResult> operation) async {
    final result = await operation;
    if (result == RewardResult.ok) state = AsyncData(await _load());
    return result;
  }

  /// ご褒美を追加する。
  Future<RewardResult> add(String name, int cost) => _reloadIfOk(
    ref
        .read(rewardRepositoryProvider)
        .addReward(name, cost, ref.read(clockProvider)()),
  );

  /// ご褒美の名前・必要ポイントを変更する。
  Future<RewardResult> updateReward(int id, String name, int cost) =>
      _reloadIfOk(
        ref.read(rewardRepositoryProvider).updateReward(id, name, cost),
      );

  /// ご褒美を削除(アーカイブ)する。交換履歴は残る。
  Future<RewardResult> archive(int id) =>
      _reloadIfOk(ref.read(rewardRepositoryProvider).archiveReward(id));

  /// ご褒美とポイントを交換する(取り消しはできない)。
  Future<RewardResult> redeem(int id) => _reloadIfOk(
    ref.read(rewardRepositoryProvider).redeem(id, ref.read(clockProvider)()),
  );
}

/// ご褒美・交換履歴・ポイントの状態。
final rewardsProvider = AsyncNotifierProvider<RewardsNotifier, RewardsState>(
  RewardsNotifier.new,
);
