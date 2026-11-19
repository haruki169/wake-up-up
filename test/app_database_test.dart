// データベース(app_database.dart)の作成とマイグレーションのテスト(実際の SQLite)。
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wake_up_up/data/app_database.dart';
import 'package:wake_up_up/data/record_repository.dart';
import 'package:wake_up_up/data/reward_repository.dart';
import 'package:wake_up_up/domain/reward.dart';

import 'helpers/db_helper.dart';
import 'helpers/fakes.dart';

Future<Set<String>> _tables(Database db) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name != 'android_metadata'",
  );
  return rows.map((r) => r['name'] as String).toSet();
}

void main() {
  test('バージョンは2', () => expect(AppDatabase.version, 2));

  test('新規作成: 3つのテーブルがすべて作られる', () async {
    final db = await TestDb.create().open();
    expect(await _tables(db), {'wake_records', 'rewards', 'redemptions'});
    expect(await db.getVersion(), 2);
  });

  group('バージョン1 → 2 のマイグレーション', () {
    test('既存の記録が失われず、新しいテーブルが追加される', () async {
      final t = TestDb.create();
      await t.createVersion1([
        rec('2026-11-18', true, points: 13),
        rec('2026-11-19', false),
      ]);

      final db = await t.open();
      expect(await db.getVersion(), 2);
      expect(await _tables(db), {'wake_records', 'rewards', 'redemptions'});

      final records = await SqliteRecordRepository(db).all();
      expect(records.map((r) => r.date), ['2026-11-19', '2026-11-18']);
      expect(records.last.points, 13);
      expect(records.last.success, isTrue);
    });

    test('更新後すぐにご褒美を使え、既存の記録の獲得ポイントが残高になる', () async {
      final t = TestDb.create();
      await t.createVersion1([rec('2026-11-18', true, points: 50)]);
      final db = await t.open();
      final repo = SqliteRewardRepository(db);
      expect(await repo.balance(), 50);
      expect(
        await repo.addReward('コーヒー', 30, DateTime(2026, 11, 20)),
        RewardResult.ok,
      );
      final id = (await repo.activeRewards()).single.id;
      expect(await repo.redeem(id, DateTime(2026, 11, 20)), RewardResult.ok);
      expect(await repo.balance(), 20);
    });

    test('記録が1件もない v1 でも更新できる', () async {
      final t = TestDb.create();
      await t.createVersion1([]);
      final db = await t.open();
      expect(await _tables(db), {'wake_records', 'rewards', 'redemptions'});
      expect(await SqliteRewardRepository(db).balance(), 0);
    });
  });

  test('開き直しても(v2 → v2)データと構造が変わらない', () async {
    final t = TestDb.create();
    var db = await t.open();
    await SqliteRecordRepository(db).insert(rec('2026-11-19', true));
    await SqliteRewardRepository(db)
        .addReward('本', 100, DateTime(2026, 11, 20));
    await db.close();

    db = await t.open();
    expect(await _tables(db), {'wake_records', 'rewards', 'redemptions'});
    expect((await SqliteRecordRepository(db).all()).length, 1);
    expect((await SqliteRewardRepository(db).activeRewards()).length, 1);
  });
}
