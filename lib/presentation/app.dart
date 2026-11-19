import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'history_page.dart';
import 'home_page.dart';
import 'providers.dart';
import 'settings_page.dart';
import 'theme_options.dart';

/// アプリ全体のルート。設定のテーマカラーを反映して [_Shell] を表示する。
class WakeUpUpApp extends ConsumerWidget {
  const WakeUpUpApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorIndex = ref.watch(
      settingsProvider.select((s) => s.themeColorIndex),
    );
    return MaterialApp(
      title: 'wake-up-up',
      theme: buildTheme(colorIndex, Brightness.light),
      home: const _Shell(),
    );
  }
}

/// 下部タブ(ホーム/履歴/設定)で3つの画面を切り替える枠組み。
class _Shell extends ConsumerStatefulWidget {
  const _Shell();

  @override
  ConsumerState<_Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<_Shell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// バックグラウンドから戻ったときに日付を再計算する。
  ///
  /// 端末のスリープ中はタイマーが進まないことがあるため、復帰時にも更新する。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(todayProvider);
    }
  }

  /// 表示中のタブの番号(0: ホーム、1: 履歴、2: 設定)。
  int _index = 0;

  /// 各タブのアプリバー用タイトル。[_pages] と同じ順序。
  static const _titles = ['ホーム', '履歴', '設定'];

  /// 各タブの画面。[_titles] と同じ順序。
  static const _pages = [HomePage(), HistoryPage(), SettingsPage()];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_titles[_index])),
    body: SafeArea(child: _pages[_index]),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.wb_sunny), label: 'ホーム'),
        NavigationDestination(icon: Icon(Icons.history), label: '履歴'),
        NavigationDestination(icon: Icon(Icons.settings), label: '設定'),
      ],
    ),
  );
}
