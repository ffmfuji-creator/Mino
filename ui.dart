import 'package:flutter/material.dart';

import 'app_state.dart';

/// 把 AppState 提供给整棵组件树。
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    return scope!.notifier!;
  }
}

Color alpha(Color c, double o) => c.withAlpha((o * 255).round());

bool isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
Color panelColor(BuildContext c) =>
    isDark(c) ? const Color(0xFF111A2E) : Colors.white;
Color lineColor(BuildContext c) =>
    isDark(c) ? const Color(0xFF1F2B47) : const Color(0xFFE2E8F0);
Color mutedColor(BuildContext c) =>
    isDark(c) ? const Color(0xFF8A97B5) : const Color(0xFF64748B);

Color priorityColor(Priority p) {
  switch (p) {
    case Priority.low:
      return const Color(0xFF34D399);
    case Priority.medium:
      return const Color(0xFFFBBF24);
    case Priority.high:
      return const Color(0xFFF87171);
  }
}

ThemeData buildTheme(bool dark) {
  final scheme = dark
      ? const ColorScheme.dark(
          primary: Color(0xFF22D3EE),
          secondary: Color(0xFF8B5CF6),
          surface: Color(0xFF111A2E),
          error: Color(0xFFF87171),
        )
      : const ColorScheme.light(
          primary: Color(0xFF0891B2),
          secondary: Color(0xFF7C3AED),
          surface: Colors.white,
          error: Color(0xFFDC2626),
        );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor:
        dark ? const Color(0xFF0A0E1A) : const Color(0xFFF1F5F9),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? const Color(0xFF0D1324) : Colors.white,
      indicatorColor: alpha(scheme.primary, 0.2),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
  );
}

/// 带细边框和微光的面板。
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.glow,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: panelColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: glow != null ? alpha(glow!, 0.5) : lineColor(context),
        ),
        boxShadow: glow == null
            ? null
            : [BoxShadow(color: alpha(glow!, 0.12), blurRadius: 24)],
      ),
      child: child,
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
          color: mutedColor(context),
        ),
      ),
    );
  }
}

String mmss(int ms) {
  final s = (ms / 1000).ceil();
  final m = s ~/ 60;
  final r = s % 60;
  return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
}

String hm(int sec) {
  final m = sec ~/ 60;
  if (m < 60) return '$m 分钟';
  return '${m ~/ 60} 小时 ${m % 60} 分';
}

Future<bool> confirmDialog(
  BuildContext context,
  String title,
  String message, {
  String okText = '确定',
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(okText),
        ),
      ],
    ),
  );
  return r ?? false;
}
