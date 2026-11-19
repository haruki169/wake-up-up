// 観点5: アクセシビリティ(タップ領域・ラベル・コントラスト)。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';

Future<void> _check(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

void main() {
  testWidgets('ホーム(未記録)', (tester) async {
    final h = tester.ensureSemantics();
    await tester.pumpWidget(
      buildApp(clock: () => DateTime(2026, 11, 19, 6, 0)),
    );
    await tester.pumpAndSettle();
    await _check(tester);
    h.dispose();
  });

  testWidgets('ホーム(成功後)', (tester) async {
    final h = tester.ensureSemantics();
    await tester.pumpWidget(
      buildApp(clock: () => DateTime(2026, 11, 19, 6, 0)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wake_button')));
    await tester.pumpAndSettle();
    await _check(tester);
    h.dispose();
  });

  testWidgets('履歴', (tester) async {
    final h = tester.ensureSemantics();
    await tester.pumpWidget(
      buildApp(
        clock: () => DateTime(2026, 11, 20, 6, 0),
        repo: FakeRecordRepository([
          rec('2026-11-18', true),
          rec('2026-11-19', false),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    await _check(tester);
    h.dispose();
  });

  testWidgets('設定', (tester) async {
    // 設定画面は項目が多いため、全体が画面に収まる高さにして確認する
    // (途中で切れた文字はコントラスト検査の誤検出になる)。
    setScreen(tester, const Size(390, 1600));
    final h = tester.ensureSemantics();
    await tester.pumpWidget(
      buildApp(clock: () => DateTime(2026, 11, 19, 6, 0)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await _check(tester);
    h.dispose();
  });

  testWidgets('「起きた」ボタンに読み上げ用のテキストがある', (tester) async {
    final h = tester.ensureSemantics();
    await tester.pumpWidget(
      buildApp(clock: () => DateTime(2026, 11, 19, 6, 0)),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.byKey(const Key('wake_button'))),
      matchesSemantics(
        label: '起きた',
        isButton: true,
        hasTapAction: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    h.dispose();
  });
}
