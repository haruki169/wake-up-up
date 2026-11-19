// ご褒美のデータ層を、端末の実際の SQLite で確認する統合テスト
// (バージョン1からのマイグレーション、交換のトランザクション、再起動後の残高)。
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:wake_up_up/data/app_database.dart';
import 'package:wake_up_up/data/record_repository.dart';
import 'package:wake_up_up/data/reward_repository.dart';
import 'package:wake_up_up/domain/reward.dart';
import 'package:wake_up_up/domain/wake_record.dart';

WakeRecord _rec(String date, bool ok, int points) => WakeRecord(
  date: date,
  wokeAt: DateTime.parse(date).add(const Duration(hours: 6)),
  targetTime: const TargetTime(6, 30),
  success: ok,
  points: points,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late String path;

  setUp(() async {
    path = p.join(await getDatabasesPath(), 'reward_it.db');
    await deleteDatabase(path);
  });

  tearDownAll(() async {
    await deleteDatabase(p.join(await getDatabasesPath(), 'reward_it.db'));
  });

  testWidgets('バージョン1のDBを開くと、記録を保ったままご褒美の機能が使える', (tester) async {
    // 旧バージョン(ご褒美なし)のDBを作る。
    final v1 = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE wake_records (
          date TEXT PRIMARY KEY,
          woke_at INTEGER NOT NULL,
          target_time TEXT NOT NULL,
          success INTEGER NOT NULL,
          points INTEGER NOT NULL
        )
      '''),
    );
    await v1.insert('wake_records', _rec('2026-11-18', true, 40).toMap());
    await v1.close();

    final db = await AppDatabase.open(path: path);
    expect(await db.getVersion(), 2);
    expect((await SqliteRecordRepository(db).all()).single.points, 40);

    final repo = SqliteRewardRepository(db);
    expect(await repo.balance(), 40);
    expect(
      await repo.addReward('コーヒー', 30, DateTime(2026, 11, 20)),
      RewardResult.ok,
    );
    final id = (await repo.activeRewards()).single.id;
    expect(await repo.redeem(id, DateTime(2026, 11, 20)), RewardResult.ok);
    expect(await repo.balance(), 10);
    await db.close();
  });

  testWidgets('交換した内容と残高が、DBを開き直しても残る', (tester) async {
    var db = await AppDatabase.open(path: path);
    await SqliteRecordRepository(db).insert(_rec('2026-11-19', true, 100));
    var repo = SqliteRewardRepository(db);
    await repo.addReward('本', 60, DateTime(2026, 11, 20));
    final id = (await repo.activeRewards()).single.id;
    expect(await repo.redeem(id, DateTime(2026, 11, 20, 8)), RewardResult.ok);
    await db.close();

    db = await AppDatabase.open(path: path);
    repo = SqliteRewardRepository(db);
    expect(await repo.balance(), 40);
    expect(await repo.totalSpent(), 60);
    expect((await repo.redemptions()).single.rewardName, '本');
    expect((await repo.activeRewards()).single.name, '本');
    await db.close();
  });

  testWidgets('連続で交換しても残高がマイナスにならない(実機のトランザクション)', (tester) async {
    final db = await AppDatabase.open(path: path);
    await SqliteRecordRepository(db).insert(_rec('2026-11-19', true, 30));
    final repo = SqliteRewardRepository(db);
    await repo.addReward('コーヒー', 10, DateTime(2026, 11, 20));
    final id = (await repo.activeRewards()).single.id;
    final results = await Future.wait([
      for (var i = 0; i < 8; i++) repo.redeem(id, DateTime(2026, 11, 20)),
    ]);
    expect(results.where((r) => r == RewardResult.ok).length, 3);
    expect(await repo.balance(), 0);
    await db.close();
  });
}
