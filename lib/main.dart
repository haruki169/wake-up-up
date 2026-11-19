import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/record_repository.dart';
import 'data/settings_repository.dart';
import 'presentation/app.dart';
import 'presentation/providers.dart';

/// アプリのエントリポイント。
///
/// 非同期で初期化が必要な保存先(SQLite、shared_preferences)を先に開き、
/// provider に注入してからアプリを起動する。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final records = await SqliteRecordRepository.open();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        recordRepositoryProvider.overrideWithValue(records),
        settingsRepositoryProvider.overrideWithValue(
          PrefsSettingsRepository(prefs),
        ),
      ],
      child: const WakeUpUpApp(),
    ),
  );
}
