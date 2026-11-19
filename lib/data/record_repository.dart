import 'package:sqflite/sqflite.dart';

import '../domain/wake_record.dart';
import 'app_database.dart';

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
  SqliteRecordRepository(this._db);

  final Database _db;

  /// アプリのデータベースを開いて、そこに保存するリポジトリを返す。
  static Future<SqliteRecordRepository> open() async =>
      SqliteRecordRepository(await AppDatabase.open());

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
