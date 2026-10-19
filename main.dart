import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'cloud_sync.dart';
import 'notifier.dart';
import 'growth_screen.dart';
import 'i18n.dart';
import 'moments_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'tasks_screen.dart';
import 'timer_screen.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Notifier.init();
  await CloudSync.init();
  final state = await AppState.load();
  runApp(MinoApp(state: state));
}

class MinoApp extends StatelessWidget {
  const MinoApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return I18nScope(
      child: AppScope(
      state: state,
      child: ValueListenableBuilder<bool>(
        valueListenable: state.darkNotifier,
        builder: (context, dark, _) => MaterialApp(
          title: 'Mino',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(false),
          darkTheme: buildTheme(true),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: HomeShell(state: state),
        ),
      ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.state});
  final AppState state;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _pages = <Widget>[
    TimerScreen(),
    TasksScreen(),
    StatsScreen(),
    GrowthScreen(),
    MomentsScreen(),
    SettingsScreen(),
  ];

  int _index = 0;
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.state.events.listen(_onEvent);
  }

  void _onEvent(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    I18nScope.watch(context); // 切换语言时刷新导航栏文字
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: _pages[_index],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.timer_outlined),
              selectedIcon: const Icon(Icons.timer),
              label: tr('专注')),
          NavigationDestination(
              icon: const Icon(Icons.checklist), label: tr('任务')),
          NavigationDestination(
              icon: const Icon(Icons.insights_outlined),
              selectedIcon: const Icon(Icons.insights),
              label: tr('统计')),
          NavigationDestination(
              icon: const Icon(Icons.emoji_events_outlined),
              selectedIcon: const Icon(Icons.emoji_events),
              label: tr('成长')),
          NavigationDestination(
              icon: const Icon(Icons.event_outlined),
              selectedIcon: const Icon(Icons.event),
              label: tr('日子')),
          NavigationDestination(
              icon: const Icon(Icons.tune), label: tr('设置')),
        ],
      ),
    );
  }
}
