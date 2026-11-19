import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/wake_record.dart';

/// 起床記録の保存先を抽象化したリポジトリ。
///
/// 本番では [SqliteRecordRepository]、テストでは差し替え用の実装を使う。
abstract class RecordRepository {
  /// すべての記録を日付の新しい順に返す。
  Future<List<WakeRecord>> all();

  /// [record] を保存する。
  ///
  /// 同じ日付の記録が既にある場合は何もせず `false` を返す(1日1回の制約)。
  /// 保存できた場合は `true`。
  Future<bool> insert(WakeRecord record);
}

/// SQLite(sqflite)に記録を保存する [RecordRepository] の実装。
class SqliteRecordRepository implements RecordRepository {
  SqliteRecordRepository._(this._db);

  final Database _db;

  /// データベースを開く。初回は `wake_records` テーブルを作成する。
  ///
  /// カラム: `date`(論理日付、主キー)、`woke_at`(起床時刻のエポックミリ秒)、
  /// `target_time`(`HH:mm`)、`success`(0/1)、`points`。
  /// 日付を主キーにすることで、1日1件の制約をデータベース側でも保証する。
  static Future<SqliteRecordRepository> open() async {
    final path = p.join(await getDatabasesPath(), 'wake_up_up.db');
    final db = await openDatabase(
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
    return SqliteRecordRepository._(db);
  }

  @override
  Future<List<WakeRecord>> all() async {
    final rows = await _db.query('wake_records', orderBy: 'date DESC');
    return rows.map(WakeRecord.fromMap).toList();
  }

  @override
  Future<bool> insert(WakeRecord record) async {
    // 主キー(date)が重複した場合は無視し、挿入された行 id は 0 になる。
    final id = await _db.insert(
      'wake_records',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return id != 0;
  }
}
