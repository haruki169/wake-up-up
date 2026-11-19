// 8色すべてのテーマで、アクセシビリティ基準(コントラスト・タップ領域・ラベル)を満たすか。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_up_up/domain/app_settings.dart';
import 'package:wake_up_up/presentation/theme_options.dart';

import 'helpers/fakes.dart';

Future<void> _check(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

void main() {
  for (var i = 0; i < themeChoices.length; i++) {
    final name = themeChoices[i].name;

    Future<void> pump(
      WidgetTester tester, {
      List<dynamic> seed = const [],
    }) async {
      setScreen(tester, const Size(390, 1200));
      await tester.pumpWidget(
        buildApp(
          clock: () => DateTime(2026, 11, 20, 6, 0),
          settings: FakeSettings(AppSettings(themeColorIndex: i)),
          repo: FakeRecordRepository([
            rec('2026-11-18', true),
            rec('2026-11-19', false),
          ]),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('$name: ホーム(未記録)', (tester) async {
      final h = tester.ensureSemantics();
      await pump(tester);
      await _check(tester);
      h.dispose();
    });

    testWidgets('$name: ホーム(成功後)', (tester) async {
      final h = tester.ensureSemantics();
      await pump(tester);
      await tester.tap(find.byKey(const Key('wake_button')));
      await tester.pumpAndSettle();
      await _check(tester);
      h.dispose();
    });

    testWidgets('$name: 履歴', (tester) async {
      final h = tester.ensureSemantics();
      await pump(tester);
      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();
      await _check(tester);
      h.dispose();
    });

    testWidgets('$name: 設定', (tester) async {
      final h = tester.ensureSemantics();
      await pump(tester);
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      await _check(tester);
      h.dispose();
    });
  }
}
