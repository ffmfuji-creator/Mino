import 'dart:async';

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'ui.dart';

String _two(int n) => n.toString().padLeft(2, '0');

String _thousands(int n) => n
    .toString()
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

String _fmt(DateTime t) =>
    '${dayKey(t)} ${_two(t.hour)}:${_two(t.minute)}';

/// 纪念日 / 倒数日：目标时间在过去 = 已过多久（正计时），在未来 = 还有多久（倒计时）。
class MomentsScreen extends StatefulWidget {
  const MomentsScreen({super.key});

  @override
  State<MomentsScreen> createState() => _MomentsScreenState();
}

class _MomentsScreenState extends State<MomentsScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final now = DateTime.now();
    final items = s.sortedMoments(now);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showMomentEditor(context, s),
        icon: const Icon(Icons.add),
        label: const Text('新日子'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text('日子',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 70),
              child: Center(
                child: Text(
                  '还没有日子\n点右下角「新日子」添加\n\n过去的日期 → 显示已经过了多久\n未来的日期 → 显示还有多久',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: mutedColor(context), height: 1.7),
                ),
              ),
            ),
          for (final m in items) _MomentCard(moment: m, state: s, now: now),
        ],
      ),
    );
  }
}

class _MomentCard extends StatelessWidget {
  const _MomentCard({
    required this.moment,
    required this.state,
    required this.now,
  });

  final Moment moment;
  final AppState state;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final diff = moment.time.difference(now);
    final isFuture = !diff.isNegative;
    final abs = diff.abs();
    final days = abs.inDays;
    final h = abs.inHours % 24;
    final m = abs.inMinutes % 60;
    final sec = abs.inSeconds % 60;
    final cs = Theme.of(context).colorScheme;
    final color = isFuture ? cs.primary : cs.secondary;

    return Dismissible(
      key: ValueKey(moment.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => confirmDialog(
          context, '删除日子', '确定删除「${moment.title}」吗？',
          okText: '删除'),
      onDismissed: (_) => state.deleteMoment(moment),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 24),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: alpha(const Color(0xFFF87171), 0.25),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline, color: Color(0xFFF87171)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => showMomentEditor(context, state, moment: moment),
          child: Panel(
            glow: color,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        moment.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: alpha(color, 0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(isFuture ? '还有' : '已过',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: color)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$days',
                        style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                            color: color)),
                    const SizedBox(width: 6),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text('天', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Unit(value: _two(h), label: '时', color: color),
                    const SizedBox(width: 10),
                    _Unit(value: _two(m), label: '分', color: color),
                    const SizedBox(width: 10),
                    _Unit(value: _two(sec), label: '秒', color: color),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${_fmt(moment.time)}  ·  共 ${_thousands(abs.inSeconds)} 秒',
                  style: TextStyle(fontSize: 12, color: mutedColor(context)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Unit extends StatelessWidget {
  const _Unit({required this.value, required this.label, required this.color});
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: alpha(color, 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: alpha(color, 0.25)),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()])),
          Text(label,
              style: TextStyle(fontSize: 11, color: mutedColor(context))),
        ],
      ),
    );
  }
}

Future<void> showMomentEditor(BuildContext context, AppState s,
    {Moment? moment}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _MomentEditor(state: s, moment: moment),
  );
}

class _MomentEditor extends StatefulWidget {
  const _MomentEditor({required this.state, this.moment});
  final AppState state;
  final Moment? moment;

  @override
  State<_MomentEditor> createState() => _MomentEditorState();
}

class _MomentEditorState extends State<_MomentEditor> {
  late final TextEditingController _controller;
  late DateTime _date;
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    final m = widget.moment;
    final base = m?.time ?? DateTime.now();
    _controller = TextEditingController(text: m?.title ?? '');
    _date = DateTime(base.year, base.month, base.day);
    _time = m == null
        ? const TimeOfDay(hour: 0, minute: 0)
        : TimeOfDay(hour: base.hour, minute: base.minute);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  void _save() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    final time = DateTime(
        _date.year, _date.month, _date.day, _time.hour, _time.minute);
    final m = widget.moment;
    if (m == null) {
      widget.state.addMoment(title, time);
    } else {
      widget.state.updateMoment(m, title: title, time: time);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.moment == null ? '新日子' : '编辑日子',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: widget.moment == null,
            maxLength: 30,
            decoration: const InputDecoration(
              labelText: '名称',
              hintText: '例如：在一起 / 距离 12 月 1 日',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(dayKey(_date)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text('${_two(_time.hour)}:${_two(_time.minute)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('选过去的时间 = 已过多久；选未来的时间 = 还有多久',
              style: TextStyle(fontSize: 12, color: mutedColor(context))),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _save, child: const Text('保存')),
          ),
        ],
      ),
    );
  }
}
