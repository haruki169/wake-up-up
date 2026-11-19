// 観点3: データの永続化(シミュレータ/実機で実際の SQLite・shared_preferences を使う)。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wake_up_up/data/record_repository.dart';
import 'package:wake_up_up/data/settings_repository.dart';
import 'package:wake_up_up/domain/app_settings.dart';
import 'package:wake_up_up/domain/wake_logic.dart';
import 'package:wake_up_up/domain/wake_record.dart';
import 'package:wake_up_up/presentation/app.dart';
import 'package:wake_up_up/presentation/providers.dart';
import 'package:wake_up_up/presentation/theme_options.dart';

/// アプリを(再)起動する。保存先を開き直し、新しい ProviderScope で構築する。
Future<Widget> _launch() async {
  final records = await SqliteRecordRepository.open();
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      recordRepositoryProvider.overrideWithValue(records),
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
    expect(find.text(logicalDate(DateTime.now())), findsOneWidget);
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
