import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// アプリのデータベース(起床記録・ご褒美・交換履歴)を開く。
///
/// バージョンの履歴:
/// - 1: `wake_records`(起床記録)
/// - 2: `rewards`(ご褒美)と `redemptions`(交換履歴)を追加
class AppDatabase {
  AppDatabase._();

  /// 現在のデータベースのバージョン。
  static const int version = 2;

  /// データベースのファイル名。
  static const String fileName = 'wake_up_up.db';

  static const _createWakeRecords = '''
    CREATE TABLE wake_records (
      date TEXT PRIMARY KEY,
      woke_at INTEGER NOT NULL,
      target_time TEXT NOT NULL,
      success INTEGER NOT NULL,
      points INTEGER NOT NULL
    )
  ''';

  static const _createRewards = '''
    CREATE TABLE rewards (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      cost INTEGER NOT NULL,
      archived INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL
    )
  ''';

  // reward_name と cost は交換した時点の値(後から編集・削除しても履歴が変わらない)。
  static const _createRedemptions = '''
    CREATE TABLE redemptions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      reward_id INTEGER,
      reward_name TEXT NOT NULL,
      cost INTEGER NOT NULL,
      redeemed_at INTEGER NOT NULL
    )
  ''';

  /// データベースを開く。なければ作成し、古いバージョンなら更新する。
  ///
  /// [factory] と [path] はテストで差し替えるための引数
  /// (省略時は端末の標準の場所に開く)。
  static Future<Database> open({DatabaseFactory? factory, String? path}) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), fileName);
    return f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: version,
        onCreate: (db, _) async {
          await db.execute(_createWakeRecords);
          await db.execute(_createRewards);
          await db.execute(_createRedemptions);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          // 既存の記録(wake_records)はそのまま残し、新しいテーブルだけ追加する。
          if (oldVersion < 2) {
            await db.execute(_createRewards);
            await db.execute(_createRedemptions);
          }
        },
      ),
    );
  }
}
