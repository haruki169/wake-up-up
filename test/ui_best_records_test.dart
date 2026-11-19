// 履歴画面のベスト記録カードのテスト。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';

Future<void> _openHistory(
  WidgetTester tester, {
  List<dynamic> records = const [],
  DateTime? now,
  Size size = const Size(390, 1200),
  double textScale = 1.0,
}) async {
  setScreen(tester, size, textScale: textScale);
  await tester.pumpWidget(
    buildApp(
      clock: () => now ?? DateTime(2026, 11, 20, 6, 0),
      repo: FakeRecordRepository(records.cast()),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.history));
  await tester.pumpAndSettle();
}

Finder _in(String key, Finder f) =>
    find.descendant(of: find.byKey(Key(key)), matching: f);

void main() {
  testWidgets('記録がないときは案内のみでカードは出ない', (tester) async {
    await _openHistory(tester);
    expect(find.text('まだ記録がありません'), findsOneWidget);
    expect(find.byKey(const Key('best_records_card')), findsNothing);
  });

  testWidgets('3つのベスト記録が正しく表示される', (tester) async {
    await _openHistory(
      tester,
      records: [
        rec('2026-11-15', true),
        rec('2026-11-16', true),
        rec('2026-11-17', true),
        rec('2026-11-18', false),
        rec('2026-11-19', true),
      ],
    );
    expect(find.byKey(const Key('best_records_card')), findsOneWidget);
    // 最長連続: 11/15〜11/17 の3日
    expect(_in('best_streak', find.text('3 日')), findsOneWidget);
    expect(
      _in('best_streak', find.text('2026-11-15 〜 2026-11-17')),
      findsOneWidget,
    );
    // 最も早い起床: rec() は 6:00 起床(同時刻は日付の古い方)
    expect(_in('best_earliest', find.text('06:00')), findsOneWidget);
    expect(_in('best_earliest', find.text('2026-11-15')), findsOneWidget);
    // 通算: 成功4日 / 記録5日 / 80%
    expect(_in('best_total', find.text('4 日')), findsOneWidget);
    expect(_in('best_total', find.text('記録 5 日中・成功率 80%')), findsOneWidget);
  });

  testWidgets('成功が1日もない場合は「—」と成功率0%', (tester) async {
    await _openHistory(tester, records: [rec('2026-11-19', false)]);
    expect(_in('best_streak', find.text('—')), findsOneWidget);
    expect(_in('best_streak', find.text('まだありません')), findsOneWidget);
    expect(_in('best_total', find.text('記録 1 日中・成功率 0%')), findsOneWidget);
    // 起床の記録はあるので、最も早い起床は表示される。
    expect(_in('best_earliest', find.text('06:00')), findsOneWidget);
  });

  testWidgets('記録が1件(成功)のとき', (tester) async {
    await _openHistory(tester, records: [rec('2026-11-19', true)]);
    expect(_in('best_streak', find.text('1 日')), findsOneWidget);
    expect(_in('best_total', find.text('記録 1 日中・成功率 100%')), findsOneWidget);
  });

  testWidgets('日ごとの記録もカードの下に表示される', (tester) async {
    await _openHistory(
      tester,
      records: [rec('2026-11-18', true), rec('2026-11-19', false)],
    );
    expect(find.text('2026-11-19'), findsWidgets);
    expect(find.text('+10 pt'), findsOneWidget);
  });

  testWidgets('新しく記録するとベスト記録が更新される', (tester) async {
    setScreen(tester, const Size(390, 1200));
    await tester.pumpWidget(
      buildApp(
        clock: () => DateTime(2026, 11, 20, 6, 0),
        repo: FakeRecordRepository([
          rec('2026-11-18', true),
          rec('2026-11-19', true),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wake_button')));
    await tester.pumpAndSettle();
    // 3日連続の節目に到達してお祝いが出るので閉じる。
    await tester.tap(find.byKey(const Key('milestone_close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    expect(_in('best_streak', find.text('3 日')), findsOneWidget);
    expect(_in('best_total', find.text('3 日')), findsOneWidget);
    // 6:00 起床(目標 6:30 より早い)で、最も早い起床は 6:00 のまま(古い日付)。
    expect(_in('best_earliest', find.text('2026-11-18')), findsOneWidget);
  });

  testWidgets('1000日分でも表示できる', (tester) async {
    final base = DateTime(2026, 11, 19);
    final seed = [
      for (var i = 0; i < 1000; i++)
        rec(fmtDate(DateTime(base.year, base.month, base.day - i)), true),
    ];
    await _openHistory(tester, records: seed);
    expect(_in('best_streak', find.text('1000 日')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('レイアウト', () {
    for (final (label, size, scale) in [
      ('通常', const Size(390, 844), 1.0),
      ('小さい画面 320x568', const Size(320, 568), 1.0),
      ('小さい画面 + 文字3倍', const Size(320, 568), 3.0),
      ('横向き 844x390', const Size(844, 390), 1.0),
    ]) {
      testWidgets('ベスト記録カードが崩れない($label)', (tester) async {
        await _openHistory(
          tester,
          records: [rec('2026-11-18', true), rec('2026-11-19', true)],
          size: size,
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        await tester.fling(find.byType(ListView), const Offset(0, -2000), 2000);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('見出しがあり、アクセシビリティ基準を満たす', (tester) async {
    final h = tester.ensureSemantics();
    await _openHistory(
      tester,
      records: [rec('2026-11-18', true), rec('2026-11-19', false)],
    );
    expect(find.text('ベスト記録'), findsOneWidget);
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    h.dispose();
  });
}
