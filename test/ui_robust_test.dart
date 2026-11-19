// 観点6: 堅牢性。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';

void main() {
  testWidgets('ボタン連打しても記録は1件だけ', (tester) async {
    final repo = FakeRecordRepository();
    await tester.pumpWidget(
      buildApp(clock: () => DateTime(2026, 11, 19, 6, 0), repo: repo),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 8; i++) {
      await tester.tap(
        find.byKey(const Key('wake_button')),
        warnIfMissed: false,
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect((await repo.all()).length, 1);
    expect(find.text('10 pt'), findsNothing); // 6:00は30分早い=13pt
    expect(find.text('13 pt'), findsOneWidget); // 二重加算されない
  });

  testWidgets('記録ゼロの履歴は案内文を表示する', (tester) async {
    await tester.pumpWidget(
      buildApp(clock: () => DateTime(2026, 11, 19, 6, 0)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    expect(find.text('まだ記録がありません'), findsOneWidget);
  });

  testWidgets('1000日分の記録でも表示でき、連続日数が正しい', (tester) async {
    final base = DateTime(2026, 11, 19);
    final seed = [
      for (var i = 0; i < 1000; i++)
        rec(fmtDate(DateTime(base.year, base.month, base.day - i)), true),
    ];
    final sw = Stopwatch()..start();
    await tester.pumpWidget(
      buildApp(
        clock: () => DateTime(2026, 11, 20, 6, 0),
        repo: FakeRecordRepository(seed),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1000 日'), findsOneWidget);
    expect(find.text('10000 pt'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    await tester.fling(find.byType(ListView), const Offset(0, -20000), 5000);
    await tester.pumpAndSettle();
    sw.stop();
    expect(tester.takeException(), isNull);
    expect(sw.elapsed, lessThan(const Duration(seconds: 10)));
  });

  testWidgets('読み込みに失敗したらエラー文を表示する(ホーム・履歴)', (tester) async {
    await tester.pumpWidget(
      buildApp(
        clock: () => DateTime(2026, 11, 19, 6, 0),
        repo: ThrowingRecordRepository(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('読み込みに失敗しました'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    expect(find.textContaining('読み込みに失敗しました'), findsOneWidget);
  });

  testWidgets('タブを素早く何度も切り替えても例外が出ない', (tester) async {
    await tester.pumpWidget(
      buildApp(clock: () => DateTime(2026, 11, 19, 6, 0)),
    );
    await tester.pumpAndSettle();
    final icons = [Icons.history, Icons.settings, Icons.wb_sunny];
    for (var i = 0; i < 30; i++) {
      await tester.tap(find.byIcon(icons[i % 3]));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('同じ日の記録が既にある状態で起動してもボタンは押せない', (tester) async {
    final repo = FakeRecordRepository([rec('2026-11-19', true)]);
    await tester.pumpWidget(
      buildApp(clock: () => DateTime(2026, 11, 19, 9, 0), repo: repo),
    );
    await tester.pumpAndSettle();
    final b = tester.widget<FilledButton>(find.byKey(const Key('wake_button')));
    expect(b.onPressed, isNull);
    expect(find.text('記録済み'), findsOneWidget);
  });
}
