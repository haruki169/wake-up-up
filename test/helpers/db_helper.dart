import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wake_up_up/data/app_database.dart';
import 'package:wake_up_up/domain/wake_record.dart';

/// テスト用のデータベースのファイルを置く、テストごとに新しい一時フォルダ。
///
/// 終了時にデータベースを閉じて、フォルダごと削除する。
class TestDb {
  TestDb._(this.dir);

  final Directory dir;

  /// データベースのファイルのパス。
  String get path => '${dir.path}/test.db';

  /// このテスト用に一時フォルダを作る。
  static TestDb create() {
    sqfliteFfiInit();
    final dir = Directory.systemTemp.createTempSync('wake_up_up_test_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    return TestDb._(dir);
  }

  /// 最新バージョンのアプリのデータベースを開く(閉じるのはテスト終了時)。
  Future<Database> open() async {
    final db = await AppDatabase.open(factory: databaseFactoryFfi, path: path);
    addTearDown(() async {
      if (db.isOpen) await db.close();
    });
    return db;
  }

  /// バージョン1(ご褒美の機能が入る前)のデータベースを作り、[records] を入れて閉じる。
  Future<void> createVersion1(List<WakeRecord> records) async {
    final db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
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
      ),
    );
    for (final r in records) {
      await db.insert('wake_records', r.toMap());
    }
    await db.close();
  }
}
