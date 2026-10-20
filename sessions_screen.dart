import 'package:flutter/material.dart' hide Text;

import 'app_state.dart';
import 'i18n.dart';
import 'ui.dart';

String _two(int n) => n.toString().padLeft(2, '0');

/// 全部专注记录，按天分组。
class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final list = s.sessionsNewestFirst;

    final count = <String, int>{};
    final minutes = <String, int>{};
    for (final x in list) {
      final k = dayKey(x.endedAt);
      count[k] = (count[k] ?? 0) + 1;
      minutes[k] = (minutes[k] ?? 0) + x.minutes;
    }

    final children = <Widget>[];
    String? last;
    for (final x in list) {
      final k = dayKey(x.endedAt);
      if (k != last) {
        last = k;
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Row(
            children: [
              Text(k,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${count[k]} 个 · ${minutes[k]} 分钟',
                  style: TextStyle(fontSize: 12, color: mutedColor(context))),
            ],
          ),
        ));
      }
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Panel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Text('${_two(x.endedAt.hour)}:${_two(x.endedAt.minute)}',
                  style: TextStyle(color: mutedColor(context))),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  x.taskTitle ?? '未关联任务',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: x.taskTitle == null ? mutedColor(context) : null),
                ),
              ),
              if (x.partial)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text('未完整',
                      style: TextStyle(
                          fontSize: 11, color: mutedColor(context))),
                ),
              Text('${x.minutes} 分钟',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary)),
            ],
          ),
        ),
      ));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('专注记录'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        scrolledUnderElevation: 0,
      ),
      body: list.isEmpty
          ? Center(
              child: Text('还没有专注记录\n完整完成一个番茄钟后会出现在这里',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: mutedColor(context), height: 1.6)),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: children,
            ),
    );
  }
}
