import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'app_state.dart';
import 'i18n.dart';

String _cell(Object? v) {
  final s = v == null ? '' : v.toString();
  if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

/// 开头加 BOM，Excel 打开中文不乱码。
String _csv(List<List<Object?>> rows) {
  final body = rows.map((r) => r.map(_cell).join(',')).join('\r\n');
  return '\uFEFF$body\r\n';
}

String _two(int n) => n.toString().padLeft(2, '0');

String _dt(DateTime d) => '${dayKey(d)} ${_two(d.hour)}:${_two(d.minute)}';

String _yn(bool b) => tr(b ? '是' : '否');

/// 把任务、专注记录、每日统计、日子导出成 CSV 表格，并调起系统分享。
class ExportService {
  /// 成功返回 null，失败返回错误信息。
  static Future<String?> exportAll(AppState s) async {
    if (kIsWeb) return tr('网页版暂不支持导出');
    try {
      final dir = await getTemporaryDirectory();
      final stamp = dayKey(DateTime.now());
      final files = <XFile>[];

      Future<void> add(String name, List<List<Object?>> rows) async {
        final f = File('${dir.path}/mino_${name}_$stamp.csv');
        await f.writeAsString(_csv(rows), flush: true);
        files.add(XFile(f.path, mimeType: 'text/csv'));
      }

      await add('tasks', [
        [
          tr('标题'),
          tr('优先级'),
          tr('标签'),
          tr('截止日期'),
          tr('状态'),
          tr('完成时间'),
          tr('番茄钟数'),
          tr('专注分钟'),
          tr('创建时间'),
        ],
        for (final t in s.tasks)
          [
            t.title,
            tr(priorityLabel(t.priority)),
            t.tag ?? '',
            t.due == null ? '' : dayKey(t.due!),
            tr(t.done ? '已完成' : '未完成'),
            t.doneAt == null ? '' : _dt(t.doneAt!),
            t.pomodoros,
            (t.focusSec / 60).round(),
            _dt(t.createdAt),
          ],
      ]);

      await add('sessions', [
        [tr('结束时间'), tr('时长（分钟）'), tr('任务'), tr('类型')],
        for (final x in s.sessionsNewestFirst)
          [_dt(x.endedAt), x.minutes, x.taskTitle ?? '', tr(x.partial ? '未完整' : '完整')],
      ]);

      final keys = s.days.keys.toList()..sort();
      await add('daily', [
        [tr('日期'), tr('专注分钟'), tr('番茄钟数'), tr('完成任务数')],
        for (final k in keys)
          [
            k,
            (s.days[k]!.focusSec / 60).round(),
            s.days[k]!.pomodoros,
            s.days[k]!.tasksDone,
          ],
      ]);

      await add('moments', [
        [tr('名称'), tr('日期时间'), tr('每年重复'), tr('置顶')],
        for (final m in s.moments)
          [m.title, _dt(m.time), _yn(m.yearly), _yn(m.pinned)],
      ]);

      await Share.shareXFiles(files, subject: 'Mino $stamp');
      return null;
    } catch (e) {
      return '${tr('导出失败')}: $e';
    }
  }
}
