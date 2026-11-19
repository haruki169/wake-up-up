// 観点2: 時刻・日付の境界。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';

Future<void> _wake(WidgetTester tester, DateTime now) async {
  await tester.pumpWidget(buildApp(clock: () => now));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('wake_button')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('目標ちょうど(6:30:00)は成功', (tester) async {
    await _wake(tester, DateTime(2026, 11, 19, 6, 30, 0));
    expect(find.text('成功！ +10 pt'), findsOneWidget);
  });

  testWidgets('目標の1分後(6:31)は失敗', (tester) async {
    await _wake(tester, DateTime(2026, 11, 19, 6, 31));
    expect(find.text('残念、目標に間に合わず'), findsOneWidget);
  });

  testWidgets('目標の1秒後(6:30:01)は失敗', (tester) async {
    await _wake(tester, DateTime(2026, 11, 19, 6, 30, 1));
    expect(find.text('残念、目標に間に合わず'), findsOneWidget);
  });

  testWidgets('2:59 は前日扱い(日付は前日・失敗)', (tester) async {
    await _wake(tester, DateTime(2026, 11, 19, 2, 59));
    expect(find.text('残念、目標に間に合わず'), findsOneWidget);
    await openHistoryList(tester);
    expect(find.byKey(const Key('day_2026-11-18')), findsOneWidget);
  });

  testWidgets('3:00 は当日扱い(日付は当日・成功)', (tester) async {
    await _wake(tester, DateTime(2026, 11, 19, 3, 0));
    // 3:30 早い → 10 + 5(上限) = 15pt
    expect(find.text('成功！ +15 pt'), findsOneWidget);
    await openHistoryList(tester);
    expect(find.byKey(const Key('day_2026-11-19')), findsOneWidget);
  });

  for (final (h, m, pts) in [
    (6, 21, 10), // 9分早い: ボーナスなし
    (6, 20, 11), // 10分早い: +1
    (6, 0, 13), // 30分早い: +3
    (5, 40, 15), // 50分早い: +5
    (4, 0, 15), // 150分早い: 上限 +5
  ]) {
    testWidgets('ボーナス: $h:$m 起床 → +$pts pt', (tester) async {
      await _wake(tester, DateTime(2026, 11, 19, h, m));
      expect(find.text('成功！ +$pts pt'), findsOneWidget);
    });
  }

  testWidgets('日付が替わると再び押せて、連続日数が増える', (tester) async {
    var now = DateTime(2026, 11, 19, 6, 0);
    await tester.pumpWidget(buildApp(clock: () => now));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wake_button')));
    await tester.pumpAndSettle();
    expect(find.text('記録済み'), findsOneWidget);
    expect(find.text('1 日'), findsOneWidget);

    // 時間が進んで日付の境界(3:00)を過ぎると、自動で翌日の表示になる。
    now = DateTime(2026, 11, 20, 6, 0);
    await tester.pump(const Duration(hours: 22));
    await tester.pumpAndSettle();
    expect(find.text('起きた'), findsOneWidget);

    await tester.tap(find.byKey(const Key('wake_button')));
    await tester.pumpAndSettle();
    expect(find.text('2 日'), findsOneWidget);
  });

  testWidgets('アプリを開いたまま3:00を過ぎると、自動で翌日の表示に切り替わる', (tester) async {
    var now = DateTime(2026, 11, 19, 6, 0);
    await tester.pumpWidget(buildApp(clock: () => now));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wake_button')));
    await tester.pumpAndSettle();
    expect(find.text('記録済み'), findsOneWidget);

    // 3:00 の直前まで時間が進んでも、まだ切り替わらない。
    now = DateTime(2026, 11, 20, 2, 59);
    await tester.pump(const Duration(hours: 20, minutes: 59));
    expect(find.text('記録済み'), findsOneWidget);

    // 3:00 を過ぎると、画面を操作しなくても未記録の表示に変わる。
    now = DateTime(2026, 11, 20, 3, 0);
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(find.text('起きた'), findsOneWidget);
    expect(find.text('今日はまだ未記録'), findsOneWidget);
    expect(find.text('1 日'), findsOneWidget); // 昨日の成功から連続日数は続く
  });

  testWidgets('バックグラウンドから復帰したときに日付を再計算する', (tester) async {
    var now = DateTime(2026, 11, 19, 6, 0);
    await tester.pumpWidget(buildApp(clock: () => now));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wake_button')));
    await tester.pumpAndSettle();
    expect(find.text('記録済み'), findsOneWidget);

    // タイマーが進まないまま(スリープ中を想定)日付が替わり、復帰する。
    now = DateTime(2026, 11, 20, 8, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('起きた'), findsOneWidget);
  });

  testWidgets('月またぎ: 11/29,11/30 に成功済みで 12/1 に成功すると 3日連続・33pt', (tester) async {
    final repo = FakeRecordRepository([
      rec('2026-11-29', true),
      rec('2026-11-30', true),
    ]);
    await tester.pumpWidget(
      buildApp(clock: () => DateTime(2026, 12, 1, 6, 0), repo: repo),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 日'), findsOneWidget); // 今日未記録 → 昨日から数える
    await tester.tap(find.byKey(const Key('wake_button')));
    await tester.pumpAndSettle();
    expect(find.text('3 日'), findsOneWidget);
    expect(find.text('33 pt'), findsOneWidget);
  });

  testWidgets('途中で失敗した日があると連続日数はそこで途切れる', (tester) async {
    final repo = FakeRecordRepository([
      rec('2026-11-16', true),
      rec('2026-11-17', false),
      rec('2026-11-18', true),
    ]);
    await tester.pumpWidget(
      buildApp(clock: () => DateTime(2026, 11, 19, 6, 0), repo: repo),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 日'), findsOneWidget);
  });

  testWidgets('年またぎ: 12/31 の記録の翌日 1/1 に連続日数が続く', (tester) async {
    final repo = FakeRecordRepository([rec('2026-12-31', true)]);
    await tester.pumpWidget(
      buildApp(clock: () => DateTime(2027, 1, 1, 6, 0), repo: repo),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wake_button')));
    await tester.pumpAndSettle();
    expect(find.text('2 日'), findsOneWidget);
  });
}
