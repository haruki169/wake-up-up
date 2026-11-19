// 観点7: 見た目の回帰(ゴールデン)。
// テスト環境では文字がテスト用フォントで描画されるため、文字の形ではなく
// 配置・色・余白・コンポーネントの変化を検出する用途。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_up_up/domain/app_settings.dart';
import 'package:wake_up_up/domain/auto_advance.dart';
import 'package:wake_up_up/domain/wake_record.dart';
import 'package:wake_up_up/presentation/app.dart';

import 'helpers/fakes.dart';

Future<void> _golden(WidgetTester tester, String name) => expectLater(
  find.byType(WakeUpUpApp),
  matchesGoldenFile('goldens/$name.png'),
);

void main() {
  testWidgets('ホーム: 未記録', (tester) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(
      buildApp(clock: () => DateTime(2026, 11, 19, 6, 0)),
    );
    await tester.pumpAndSettle();
    await _golden(tester, 'home_unrecorded');
  });

  testWidgets('ホーム: 成功', (tester) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(
      buildApp(clock: () => DateTime(2026, 11, 19, 6, 0)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wake_button')));
    await tester.pumpAndSettle();
    await _golden(tester, 'home_success');
  });

  testWidgets('ホーム: 失敗', (tester) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(
      buildApp(clock: () => DateTime(2026, 11, 19, 8, 0)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wake_button')));
    await tester.pumpAndSettle();
    await _golden(tester, 'home_failure');
  });

  testWidgets('履歴', (tester) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(
      buildApp(
        clock: () => DateTime(2026, 11, 20, 6, 0),
        repo: FakeRecordRepository([
          rec('2026-11-17', true),
          rec('2026-11-18', false),
          rec('2026-11-19', true),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    await _golden(tester, 'history');
  });

  testWidgets('設定', (tester) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(
      buildApp(clock: () => DateTime(2026, 11, 19, 6, 0)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await _golden(tester, 'settings');
  });

  testWidgets('ホーム: 成功(青のテーマ)', (tester) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(
      buildApp(
        clock: () => DateTime(2026, 11, 19, 6, 0),
        settings: FakeSettings(const AppSettings(themeColorIndex: 4)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wake_button')));
    await tester.pumpAndSettle();
    await _golden(tester, 'home_success_blue');
  });

  testWidgets('設定(紫のテーマ・テーマカラー選択中)', (tester) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(
      buildApp(
        clock: () => DateTime(2026, 11, 19, 6, 0),
        settings: FakeSettings(const AppSettings(themeColorIndex: 3)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await _golden(tester, 'settings_purple');
  });

  testWidgets('ホーム: 成功(ダーク)', (tester) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(
      buildApp(
        clock: () => DateTime(2026, 11, 19, 6, 0),
        settings: FakeSettings(const AppSettings(themeMode: AppThemeMode.dark)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wake_button')));
    await tester.pumpAndSettle();
    await _golden(tester, 'home_success_dark');
  });

  testWidgets('履歴(ダーク)', (tester) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(
      buildApp(
        clock: () => DateTime(2026, 11, 20, 6, 0),
        settings: FakeSettings(const AppSettings(themeMode: AppThemeMode.dark)),
        repo: FakeRecordRepository([
          rec('2026-11-18', true),
          rec('2026-11-19', false),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    await _golden(tester, 'history_dark');
  });

  testWidgets('設定(ダーク)', (tester) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(
      buildApp(
        clock: () => DateTime(2026, 11, 19, 6, 0),
        settings: FakeSettings(const AppSettings(themeMode: AppThemeMode.dark)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await _golden(tester, 'settings_dark');
  });

  testWidgets('ホーム: 文言とアイコンを変更', (tester) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(
      buildApp(
        clock: () => DateTime(2026, 11, 19, 6, 0),
        settings: FakeSettings(
          const AppSettings(wakeLabel: '朝活スタート', wakeIconKey: 'rocket'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _golden(tester, 'home_custom_button');
  });

  testWidgets('設定: ホームのボタンのセクション', (tester) async {
    setScreen(tester, const Size(390, 1500));
    await tester.pumpWidget(
      buildApp(
        clock: () => DateTime(2026, 11, 19, 6, 0),
        settings: FakeSettings(
          const AppSettings(wakeLabel: '朝活', wakeIconKey: 'coffee'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await _golden(tester, 'settings_full');
  });

  testWidgets('履歴: ベスト記録カード', (tester) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(
      buildApp(
        clock: () => DateTime(2026, 11, 21, 6, 0),
        repo: FakeRecordRepository([
          rec('2026-11-16', true),
          rec('2026-11-17', true),
          rec('2026-11-18', true),
          rec('2026-11-19', false),
          rec('2026-11-20', true),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    await _golden(tester, 'history_best_records');
  });

  testWidgets('節目のお祝いダイアログ(7日連続)', (tester) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(
      buildApp(
        clock: () => DateTime(2026, 11, 7, 6, 0),
        repo: FakeRecordRepository([
          for (var i = 1; i <= 6; i++) rec('2026-11-0$i', true),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wake_button')));
    await tester.pumpAndSettle();
    await _golden(tester, 'milestone_dialog');
  });

  testWidgets('履歴: バッジ一覧(7日取得)', (tester) async {
    setScreen(tester, const Size(390, 1000));
    await tester.pumpWidget(
      buildApp(
        clock: () => DateTime(2026, 11, 20, 6, 0),
        repo: FakeRecordRepository([
          for (var i = 1; i <= 7; i++) rec('2026-11-0$i', true),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    await _golden(tester, 'history_badges');
  });

  testWidgets('履歴: カレンダー(成功・失敗・今日・未来)', (tester) async {
    setScreen(tester, const Size(390, 1500));
    await tester.pumpWidget(
      buildApp(
        clock: () => DateTime(2026, 11, 20, 6, 0),
        repo: FakeRecordRepository([
          rec('2026-11-02', true),
          rec('2026-11-03', true),
          rec('2026-11-04', false),
          rec('2026-11-09', true),
          rec('2026-11-16', true),
          rec('2026-11-17', true),
          rec('2026-11-18', false),
          rec('2026-11-19', true),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    await _golden(tester, 'calendar');
  });

  testWidgets('履歴: カレンダー(ダーク)', (tester) async {
    setScreen(tester, const Size(390, 1500));
    await tester.pumpWidget(
      buildApp(
        clock: () => DateTime(2026, 11, 20, 6, 0),
        settings: FakeSettings(const AppSettings(themeMode: AppThemeMode.dark)),
        repo: FakeRecordRepository([
          rec('2026-11-02', true),
          rec('2026-11-04', false),
          rec('2026-11-19', true),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    await _golden(tester, 'calendar_dark');
  });

  testWidgets('履歴: 日付をタップした詳細シート', (tester) async {
    setScreen(tester, const Size(390, 844));
    await tester.pumpWidget(
      buildApp(
        clock: () => DateTime(2026, 11, 20, 6, 0),
        repo: FakeRecordRepository([rec('2026-11-19', true)]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('cell_2026-11-19')),
      200,
    );
    await tester.ensureVisible(find.byKey(const Key('cell_2026-11-19')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cell_2026-11-19')));
    await tester.pumpAndSettle();
    await _golden(tester, 'calendar_day_sheet');
  });

  /// ご褒美タブを開く(獲得 [points]pt、登録済みのご褒美、交換済みの名前)。
  Future<FakeRewardRepository> openRewards(
    WidgetTester tester, {
    int points = 120,
    bool withRewards = true,
    AppSettings? settings,
    Size size = const Size(390, 1500),
  }) async {
    setScreen(tester, size);
    final records = FakeRecordRepository([
      rec('2026-11-19', true, points: points),
    ]);
    final rewards = FakeRewardRepository(records);
    if (withRewards) {
      await rewards.addReward('好きなお菓子', 100, DateTime(2026, 11, 20));
      await rewards.addReward('映画', 500, DateTime(2026, 11, 20));
    }
    await tester.pumpWidget(
      buildApp(
        clock: () => DateTime(2026, 11, 20, 6, 0),
        repo: records,
        rewards: rewards,
        settings: settings == null ? null : FakeSettings(settings),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.card_giftcard));
    await tester.pumpAndSettle();
    return rewards;
  }

  testWidgets('ご褒美: 空の状態(候補)', (tester) async {
    await openRewards(tester, withRewards: false, points: 0);
    await _golden(tester, 'rewards_empty');
  });

  testWidgets('ご褒美: 一覧(交換できる/あと少し)と交換履歴', (tester) async {
    await openRewards(tester, points: 220);
    // 画面から「好きなお菓子」を交換して、残高・使用済み・履歴を出す。
    await tester.tap(find.byKey(const Key('redeem_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_redeem')));
    await tester.pumpAndSettle();
    await _golden(tester, 'rewards_list');
  });

  testWidgets('ご褒美: 一覧(ダーク)', (tester) async {
    await openRewards(
      tester,
      settings: const AppSettings(themeMode: AppThemeMode.dark),
    );
    await _golden(tester, 'rewards_dark');
  });

  testWidgets('ご褒美: 交換の確認ダイアログ', (tester) async {
    await openRewards(tester, size: const Size(390, 844));
    await tester.tap(find.byKey(const Key('redeem_1')));
    await tester.pumpAndSettle();
    await _golden(tester, 'rewards_redeem_dialog');
  });

  testWidgets('ご褒美: 追加ダイアログ(入力エラー)', (tester) async {
    await openRewards(tester, size: const Size(390, 844));
    await tester.tap(find.byKey(const Key('add_reward')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reward_save')));
    await tester.pumpAndSettle();
    await _golden(tester, 'rewards_editor_error');
  });

  testWidgets('設定: 自動前倒しをオン', (tester) async {
    setScreen(tester, const Size(390, 1900));
    await tester.pumpWidget(
      buildApp(
        clock: () => DateTime(2026, 11, 20, 6, 0),
        settings: FakeSettings(
          const AppSettings(
            targetTime: TargetTime(7, 0),
            autoAdvance: AutoAdvance(enabled: true, days: 7, minutes: 15),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await _golden(tester, 'settings_auto_advance');
  });

  for (final reached in [false, true]) {
    testWidgets('目標の前倒しダイアログ(到達=$reached)', (tester) async {
      setScreen(tester, const Size(390, 844));
      final target = reached
          ? const TargetTime(6, 15)
          : const TargetTime(6, 30);
      await tester.pumpWidget(
        buildApp(
          clock: () => DateTime(2026, 11, 20, 6, 0),
          settings: FakeSettings(
            AppSettings(
              targetTime: target,
              autoAdvance: const AutoAdvance(enabled: true),
            ),
          ),
          // 6日連続の成功(同じ目標)が済んでいて、今日で7日目。
          repo: FakeRecordRepository([
            for (var n = 14; n <= 19; n++)
              rec('2026-11-$n', true, target: target),
          ]),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wake_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('milestone_close')));
      await tester.pumpAndSettle();
      await _golden(tester, reached ? 'advance_dialog_goal' : 'advance_dialog');
    });
  }
}
