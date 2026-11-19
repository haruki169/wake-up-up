// 観点3: データの永続化(シミュレータ/実機で実際の SQLite・shared_preferences を使う)。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wake_up_up/data/app_database.dart';
import 'package:wake_up_up/data/record_repository.dart';
import 'package:wake_up_up/data/reward_repository.dart';
import 'package:wake_up_up/data/settings_repository.dart';
import 'package:wake_up_up/domain/app_settings.dart';
import 'package:wake_up_up/domain/auto_advance.dart';
import 'package:wake_up_up/domain/wake_logic.dart';
import 'package:wake_up_up/domain/wake_record.dart';
import 'package:wake_up_up/presentation/app.dart';
import 'package:wake_up_up/presentation/providers.dart';
import 'package:wake_up_up/presentation/theme_options.dart';

/// アプリを(再)起動する。保存先を開き直し、新しい ProviderScope で構築する。
Future<Widget> _launch() async {
  final db = await AppDatabase.open();
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      recordRepositoryProvider.overrideWithValue(SqliteRecordRepository(db)),
      rewardRepositoryProvider.overrideWithValue(SqliteRewardRepository(db)),
      settingsRepositoryProvider.overrideWithValue(
        PrefsSettingsRepository(prefs),
      ),
    ],
    child: const WakeUpUpApp(),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    final path = p.join(await getDatabasesPath(), 'wake_up_up.db');
    await deleteDatabase(path);
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  });

  testWidgets('記録が実際のDBに書き込まれ、再起動後も残る', (tester) async {
    await tester.pumpWidget(await _launch());
    await tester.pumpAndSettle();
    expect(find.text('今日はまだ未記録'), findsOneWidget);

    await tester.tap(find.byKey(const Key('wake_button')));
    await tester.pumpAndSettle();
    expect(find.text('記録済み'), findsOneWidget);

    // DBファイルを直接読んで、1件書き込まれていることを確認する。
    final db = await openDatabase(
      p.join(await getDatabasesPath(), 'wake_up_up.db'),
    );
    final rows = await db.query('wake_records');
    await db.close();
    expect(rows.length, 1);
    expect(rows.single['date'], logicalDate(DateTime.now()));

    // 画面を破棄して作り直す(再起動の代わり)。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(await _launch());
    await tester.pumpAndSettle();
    expect(find.text('記録済み'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    final today = logicalDate(DateTime.now());
    // カレンダー(初期表示)に、今日の記録が成功または失敗のマークで出る。
    final cell = find.byKey(Key('cell_$today'));
    await tester.scrollUntilVisible(cell, 200);
    expect(
      find.descendant(
        of: cell,
        matching: find.byWidgetPredicate(
          (w) => w is Icon && (w.icon == Icons.check || w.icon == Icons.close),
        ),
      ),
      findsOneWidget,
    );
    // リストに切り替えると日ごとの行が出る。
    await tester.scrollUntilVisible(find.byKey(const Key('view_list')), 200);
    await tester.tap(find.byKey(const Key('view_list')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('day_$today')), findsOneWidget);
  });

  testWidgets('同じ日の2件目はDBに入らない(日付が主キー)', (tester) async {
    final repo = await SqliteRecordRepository.open();
    final r = buildRecord(DateTime.now(), const TargetTime(7, 0));
    expect(await repo.insert(r), isTrue);
    expect(await repo.insert(r), isFalse);
    expect((await repo.all()).length, 1);
  });

  testWidgets('目標時刻の設定が再起動後も残る', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await PrefsSettingsRepository(prefs)
        .save(const AppSettings(targetTime: TargetTime(5, 45)));

    await tester.pumpWidget(await _launch());
    await tester.pumpAndSettle();
    expect(find.text('目標 05:45'), findsOneWidget);
  });

  testWidgets('テーマカラーを選ぶと保存され、再起動後も維持される', (tester) async {
    await tester.pumpWidget(await _launch());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('color_chip_4')));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(await _launch());
    await tester.pumpAndSettle();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(
      app.theme!.colorScheme.primary,
      buildTheme(4, Brightness.light).colorScheme.primary,
    );
  });

  testWidgets('ダークモードを選ぶと保存され、再起動後も維持される', (tester) async {
    await tester.pumpWidget(await _launch());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ダーク'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(await _launch());
    await tester.pumpAndSettle();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('ボタンの文言とアイコンが保存され、再起動後のホームに反映される', (tester) async {
    await tester.pumpWidget(await _launch());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('label_field')), '朝活');
    await tester.pumpAndSettle();
    // 入力欄のフォーカスを外し、チップが画面内に完全に入るまでスクロールする。
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('icon_chip_rocket')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('icon_chip_rocket')));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(await _launch());
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('wake_button'));
    expect(
      find.descendant(of: button, matching: find.text('朝活')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: button, matching: find.byIcon(Icons.rocket_launch)),
      findsOneWidget,
    );
  });

  testWidgets('実際のDBの記録で、3日連続の節目のお祝いが出る(初回のみ)', (tester) async {
    // 一昨日・昨日の成功を実DBに入れてから起動する。
    final repo = await SqliteRecordRepository.open();
    final now = DateTime.now();
    for (final back in [2, 1]) {
      final day = DateTime(now.year, now.month, now.day - back, 6, 0);
      await repo.insert(buildRecord(day, const TargetTime(23, 59)));
    }
    await tester.pumpWidget(await _launch());
    await tester.pumpAndSettle();
    // 目標を 23:59 にして、いつ実行しても今日が成功になるようにする。
    final prefs = await SharedPreferences.getInstance();
    await PrefsSettingsRepository(prefs)
        .save(const AppSettings(targetTime: TargetTime(23, 59)));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(await _launch());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('wake_button')));
    await tester.pumpAndSettle();
    // 午前3:00 より前に実行すると今日が前日扱いになり節目にならないため、時刻で分岐する。
    if (now.hour >= 3) {
      expect(find.byKey(const Key('milestone_dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('milestone_close')));
      await tester.pumpAndSettle();
    }
    expect(find.text('記録済み'), findsOneWidget);

    // 履歴にバッジ(3日)が出る。
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('badges_card')), findsOneWidget);
  });

  testWidgets('ご褒美を登録して交換すると、再起動後も残高・履歴・ご褒美が残る', (tester) async {
    // 実DBに獲得ポイント(100pt)を入れてから起動する。
    final repo = await SqliteRecordRepository.open();
    await repo.insert(
      buildRecord(DateTime(2026, 11, 18, 6, 0), const TargetTime(23, 59)),
    );
    final earned = (await repo.all()).single.points;

    await tester.pumpWidget(await _launch());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.card_giftcard));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('empty_rewards')), findsOneWidget);

    // 追加
    await tester.tap(find.byKey(const Key('add_reward')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('reward_name')), 'コーヒー');
    await tester.enterText(find.byKey(const Key('reward_cost')), '10');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reward_save')));
    await tester.pumpAndSettle();
    expect(find.text('必要 10 pt'), findsOneWidget);

    // 交換
    await tester.tap(find.byKey(const Key('redeem_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_redeem')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('balance_value'))).data,
      '${earned - 10} pt',
    );

    // 再起動後も残る
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(await _launch());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.card_giftcard));
    await tester.pumpAndSettle();
    expect(find.text('必要 10 pt'), findsOneWidget);
    expect(find.byKey(const Key('redemption_1')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('spent_value'))).data,
      '使用済み 10 pt',
    );
  });

  testWidgets('7日連続で目標が前倒しされ、再起動後も新しい目標と設定が残る', (tester) async {
    // 目標 23:59 で、直近6日間(今日の前日まで)成功した記録を実DBに入れる。
    const target = TargetTime(23, 59);
    final repo = await SqliteRecordRepository.open();
    final today = logicalDate(DateTime.now());
    final todayDay = DateTime.parse(today);
    for (var back = 6; back >= 1; back--) {
      final day = DateTime(
        todayDay.year,
        todayDay.month,
        todayDay.day - back,
        6,
        0,
      );
      await repo.insert(buildRecord(day, target));
    }
    final prefs = await SharedPreferences.getInstance();
    await PrefsSettingsRepository(prefs).save(
      const AppSettings(
        targetTime: target,
        autoAdvance: AutoAdvance(enabled: true, days: 7, minutes: 30),
      ),
    );

    await tester.pumpWidget(await _launch());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wake_button')));
    await tester.pumpAndSettle();

    // 午前3:00 より前に実行すると、押した時刻が前日の目標(23:59)を過ぎて失敗になり、
    // 前倒しされない。時刻によって期待を切り替える。
    final succeeds = DateTime.now().hour >= 3;
    if (succeeds) {
      // 7日連続の節目 → 前倒しの順にダイアログが出る。
      expect(find.byKey(const Key('milestone_dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('milestone_close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('advance_dialog')), findsOneWidget);
      expect(find.textContaining('23:59 → 23:29'), findsOneWidget);
      await tester.tap(find.byKey(const Key('advance_close')));
      await tester.pumpAndSettle();
      expect(find.text('目標 23:29'), findsOneWidget);
    } else {
      expect(find.byKey(const Key('advance_dialog')), findsNothing);
      expect(find.text('目標 23:59'), findsOneWidget);
    }
    final expectedTarget = succeeds ? const TargetTime(23, 29) : target;

    // 再起動後も、新しい目標と自動前倒しの設定が残る。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(await _launch());
    await tester.pumpAndSettle();
    expect(find.text('目標 $expectedTarget'), findsOneWidget);
    final saved = PrefsSettingsRepository(await SharedPreferences.getInstance())
        .load();
    expect(saved.targetTime, expectedTarget);
    expect(saved.autoAdvance.enabled, isTrue);
    expect(saved.autoAdvance.minutes, 30);
    // 今日の記録は古い目標(23:59)で保存されている。
    final todayRecord = (await (await SqliteRecordRepository.open()).all())
        .firstWhere((r) => r.date == today);
    expect(todayRecord.targetTime, target);
  });

  testWidgets('保存した記録の内容(目標・成否・ポイント)が正しく復元される', (tester) async {
    final repo = await SqliteRecordRepository.open();
    final woke = DateTime(2026, 11, 19, 6, 20);
    await repo.insert(buildRecord(woke, const TargetTime(6, 30)));
    final got = (await repo.all()).single;
    expect(got.date, '2026-11-19');
    expect(got.wokeAt, woke);
    expect(got.targetTime, const TargetTime(6, 30));
    expect(got.success, isTrue);
    expect(got.points, 11);
  });
}
