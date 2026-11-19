import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';

void main() {
  testWidgets('目標より早く押すと成功しポイントが入る', (tester) async {
    await tester.pumpWidget(
      buildApp(clock: () => DateTime(2026, 11, 19, 6, 20)),
    );
    await tester.pumpAndSettle();
    expect(find.text('今日はまだ未記録'), findsOneWidget);

    await tester.tap(find.byKey(const Key('wake_button')));
    await tester.pumpAndSettle();

    expect(find.text('成功！ +11 pt'), findsOneWidget);
    expect(find.text('11 pt'), findsOneWidget);
    expect(find.text('1 日'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('wake_button')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('目標に遅れると失敗でポイントなし', (tester) async {
    await tester.pumpWidget(
      buildApp(clock: () => DateTime(2026, 11, 19, 8, 0)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wake_button')));
    await tester.pumpAndSettle();

    expect(find.text('残念、目標に間に合わず'), findsOneWidget);
    expect(find.text('0 pt'), findsOneWidget);
  });

  testWidgets('履歴画面に記録が表示される', (tester) async {
    await tester.pumpWidget(
      buildApp(clock: () => DateTime(2026, 11, 19, 6, 20)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wake_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('履歴').last);
    await tester.pumpAndSettle();
    expect(find.text('2026-11-19'), findsOneWidget);
    expect(find.text('+11 pt'), findsOneWidget);
  });
}
