// ライト/ダーク × 8色すべてのテーマで、アクセシビリティ基準
// (コントラスト・タップ領域・ラベル)を満たすか。
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
  for (final mode in [AppThemeMode.light, AppThemeMode.dark]) {
    for (var i = 0; i < themeChoices.length; i++) {
      final name =
          '${mode == AppThemeMode.dark ? 'ダーク' : 'ライト'}/${themeChoices[i].name}';

      Future<void> pump(WidgetTester tester) async {
        setScreen(tester, const Size(390, 1600));
        final records = FakeRecordRepository([
          rec('2026-11-18', true),
          rec('2026-11-19', false),
        ]);
        // ご褒美タブ用: 交換できるもの・できないものを1つずつ。
        final rewards = FakeRewardRepository(records);
        await rewards.addReward('コーヒー', 10, DateTime(2026, 11, 20));
        await rewards.addReward('映画', 500, DateTime(2026, 11, 20));
        await tester.pumpWidget(
          buildApp(
            clock: () => DateTime(2026, 11, 20, 6, 0),
            settings: FakeSettings(
              AppSettings(themeColorIndex: i, themeMode: mode),
            ),
            repo: records,
            rewards: rewards,
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

      testWidgets('$name: ご褒美', (tester) async {
        final h = tester.ensureSemantics();
        await pump(tester);
        await tester.tap(find.byIcon(Icons.card_giftcard));
        await tester.pumpAndSettle();
        await _check(tester);
        h.dispose();
      });
    }
  }
}
