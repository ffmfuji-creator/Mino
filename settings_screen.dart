import 'package:flutter/material.dart';

import 'account_ui.dart';
import 'app_state.dart';
import 'ui.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final st = s.settings;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 4),
          child: Text('设置',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        ),
        const SectionTitle('账号'),
        const AccountSection(),
        const SectionTitle('时长（分钟）'),
        Panel(
          child: Column(
            children: [
              _SliderRow(
                label: '专注',
                value: st.focusMin,
                min: 1,
                max: 90,
                onChanged: (v) => s.updateSettings((x) => x.focusMin = v),
              ),
              _SliderRow(
                label: '短休息',
                value: st.shortMin,
                min: 1,
                max: 30,
                onChanged: (v) => s.updateSettings((x) => x.shortMin = v),
              ),
              _SliderRow(
                label: '长休息',
                value: st.longMin,
                min: 5,
                max: 60,
                onChanged: (v) => s.updateSettings((x) => x.longMin = v),
              ),
              _SliderRow(
                label: '长休息间隔（个番茄钟）',
                value: st.longEvery,
                min: 2,
                max: 8,
                onChanged: (v) => s.updateSettings((x) => x.longEvery = v),
              ),
            ],
          ),
        ),
        const SectionTitle('行为与提醒'),
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('自动切换下一阶段'),
                subtitle: const Text('专注与休息结束后自动开始下一段'),
                value: st.autoStart,
                onChanged: (v) => s.updateSettings((x) => x.autoStart = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('提示音'),
                subtitle: const Text('应用内和后台通知都会使用'),
                value: st.sound,
                onChanged: (v) => s.updateSettings((x) => x.sound = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('振动'),
                value: st.vibrate,
                onChanged: (v) => s.updateSettings((x) => x.vibrate = v),
              ),
            ],
          ),
        ),
        const SectionTitle('外观'),
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('深色主题'),
            value: st.darkMode,
            onChanged: (v) => s.updateSettings((x) => x.darkMode = v),
          ),
        ),
        const SectionTitle('数据'),
        OutlinedButton.icon(
          onPressed: () async {
            final ok = await confirmDialog(
                context, '清除所有数据', '任务、统计、经验和设置都会被清空，且无法恢复。',
                okText: '清除');
            if (ok) await s.resetAll();
          },
          icon: const Icon(Icons.delete_forever_outlined),
          label: const Text('清除所有数据'),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text('Mino v0.4.0',
              style: TextStyle(fontSize: 12, color: mutedColor(context))),
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final String label;
  final int value;
  final int min;
  final int max;
  final void Function(int v) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label),
            const Spacer(),
            Text('$value',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary)),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}
