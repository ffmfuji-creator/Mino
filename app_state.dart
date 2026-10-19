import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_sync.dart';
import 'effects.dart';
import 'i18n.dart' show I18n;
import 'notifier.dart';

enum Priority { low, medium, high }

enum Phase { focus, shortBreak, longBreak }

enum RunStatus { idle, running, paused }

String priorityLabel(Priority p) {
  switch (p) {
    case Priority.low:
      return '低';
    case Priority.medium:
      return '中';
    case Priority.high:
      return '高';
  }
}

String phaseLabel(Phase p) {
  switch (p) {
    case Phase.focus:
      return '专注';
    case Phase.shortBreak:
      return '短休息';
    case Phase.longBreak:
      return '长休息';
  }
}

int _ci(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ───────────────────────── 数据模型 ─────────────────────────

class TaskItem {
  TaskItem({
    required this.id,
    required this.title,
    this.priority = Priority.medium,
    this.done = false,
    this.rewarded = false,
    this.pomodoros = 0,
    this.focusSec = 0,
    this.due,
    this.tag,
    DateTime? createdAt,
    this.doneAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  String title;
  Priority priority;
  bool done;
  bool rewarded;
  int pomodoros;
  int focusSec; // 在这个任务上累计专注的秒数
  DateTime? due; // 截止日期（只看日期）
  String? tag; // 分类标签
  final DateTime createdAt;
  DateTime? doneAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'priority': priority.index,
        'done': done,
        'rewarded': rewarded,
        'pomodoros': pomodoros,
        'focusSec': focusSec,
        'due': due?.millisecondsSinceEpoch,
        'tag': tag,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'doneAt': doneAt?.millisecondsSinceEpoch,
      };

  static TaskItem fromJson(Map<String, dynamic> j) {
    final doneAtMs = j['doneAt'] as int?;
    final dueMs = j['due'] as int?;
    return TaskItem(
      id: j['id'] as String,
      title: j['title'] as String,
      priority: Priority.values[_ci(j['priority'] as int? ?? 1, 0, 2)],
      done: j['done'] as bool? ?? false,
      rewarded: j['rewarded'] as bool? ?? false,
      pomodoros: j['pomodoros'] as int? ?? 0,
      focusSec: j['focusSec'] as int? ?? 0,
      due: dueMs == null ? null : DateTime.fromMillisecondsSinceEpoch(dueMs),
      tag: j['tag'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          j['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch),
      doneAt: doneAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(doneAtMs),
    );
  }
}

class Settings {
  int focusMin = 25;
  int shortMin = 5;
  int longMin = 15;
  int longEvery = 4;
  bool autoStart = true;
  bool sound = true;
  bool vibrate = true;
  bool darkMode = true;
  String language = 'zh'; // zh / en / auto（跟随系统）
  bool keepAwake = true; // 计时中保持屏幕常亮
  String ambient = 'none'; // none / white / brown / rain
  int ambientVolume = 50;
  bool ambientOnlyFocus = true; // 只在专注阶段播放白噪音
  bool dndTip = true; // 专注时提示开启勿扰

  Map<String, dynamic> toJson() => {
        'focusMin': focusMin,
        'shortMin': shortMin,
        'longMin': longMin,
        'longEvery': longEvery,
        'autoStart': autoStart,
        'sound': sound,
        'vibrate': vibrate,
        'darkMode': darkMode,
        'language': language,
        'keepAwake': keepAwake,
        'ambient': ambient,
        'ambientVolume': ambientVolume,
        'ambientOnlyFocus': ambientOnlyFocus,
        'dndTip': dndTip,
      };

  static Settings fromJson(Map<String, dynamic> j) {
    final s = Settings();
    s.focusMin = _ci(j['focusMin'] as int? ?? 25, 1, 180);
    s.shortMin = _ci(j['shortMin'] as int? ?? 5, 1, 60);
    s.longMin = _ci(j['longMin'] as int? ?? 15, 1, 120);
    s.longEvery = _ci(j['longEvery'] as int? ?? 4, 2, 10);
    s.autoStart = j['autoStart'] as bool? ?? true;
    s.sound = j['sound'] as bool? ?? true;
    s.vibrate = j['vibrate'] as bool? ?? true;
    s.darkMode = j['darkMode'] as bool? ?? true;
    final lang = j['language'] as String? ?? 'zh';
    s.language = (lang == 'zh' || lang == 'en' || lang == 'auto') ? lang : 'zh';
    s.keepAwake = j['keepAwake'] as bool? ?? true;
    final amb = j['ambient'] as String? ?? 'none';
    s.ambient = (amb == 'white' || amb == 'brown' || amb == 'rain') ? amb : 'none';
    s.ambientVolume = _ci(j['ambientVolume'] as int? ?? 50, 0, 100);
    s.ambientOnlyFocus = j['ambientOnlyFocus'] as bool? ?? true;
    s.dndTip = j['dndTip'] as bool? ?? true;
    return s;
  }
}

class DayStat {
  DayStat({this.focusSec = 0, this.pomodoros = 0, this.tasksDone = 0});
  int focusSec;
  int pomodoros;
  int tasksDone;

  Map<String, dynamic> toJson() => {
        'focusSec': focusSec,
        'pomodoros': pomodoros,
        'tasksDone': tasksDone,
      };

  static DayStat fromJson(Map<String, dynamic> j) => DayStat(
        focusSec: j['focusSec'] as int? ?? 0,
        pomodoros: j['pomodoros'] as int? ?? 0,
        tasksDone: j['tasksDone'] as int? ?? 0,
      );
}

class Moment {
  Moment({
    required this.id,
    required this.title,
    required this.time,
    this.pinned = false,
    this.yearly = false,
  });
  final String id;
  String title;
  DateTime time;
  bool pinned; // 置顶
  bool yearly; // 每年重复（生日、周年）

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'time': time.millisecondsSinceEpoch,
        'pinned': pinned,
        'yearly': yearly,
      };

  static Moment fromJson(Map<String, dynamic> j) => Moment(
        id: j['id'] as String,
        title: j['title'] as String,
        time: DateTime.fromMillisecondsSinceEpoch(j['time'] as int),
        pinned: j['pinned'] as bool? ?? false,
        yearly: j['yearly'] as bool? ?? false,
      );
}

DateTime _yearlyAt(Moment m, int year) {
  final month = m.time.month;
  var day = m.time.day;
  if (month == 2 && day == 29) {
    final leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
    if (!leap) day = 28;
  }
  return DateTime(year, month, day, m.time.hour, m.time.minute);
}

/// 日子当前倒数/正数所指向的时间点。每年重复的日子指向「下一次」。
DateTime momentTarget(Moment m, DateTime now) {
  if (!m.yearly) return m.time;
  if (m.time.isAfter(now)) return m.time;
  var cand = _yearlyAt(m, now.year);
  if (cand.isBefore(now)) cand = _yearlyAt(m, now.year + 1);
  return cand;
}

/// 两个时间点之间相差几年几个月几天（from 不晚于 to）。
List<int> calendarDiff(DateTime from, DateTime to) {
  var y = to.year - from.year;
  var mo = to.month - from.month;
  var d = to.day - from.day;
  final toSec = to.hour * 3600 + to.minute * 60 + to.second;
  final fromSec = from.hour * 3600 + from.minute * 60 + from.second;
  if (toSec < fromSec) d -= 1;
  if (d < 0) {
    mo -= 1;
    d += DateTime(to.year, to.month, 0).day; // 上个月的天数
  }
  if (mo < 0) {
    y -= 1;
    mo += 12;
  }
  if (y < 0) return [0, 0, 0];
  return [y, mo, d];
}

/// 一次完整的专注记录。
class Session {
  Session({
    required this.id,
    required this.endedAt,
    required this.minutes,
    this.taskId,
    this.taskTitle,
  });
  final String id;
  final DateTime endedAt;
  final int minutes;
  final String? taskId;
  final String? taskTitle;

  Map<String, dynamic> toJson() => {
        'id': id,
        'endedAt': endedAt.millisecondsSinceEpoch,
        'minutes': minutes,
        'taskId': taskId,
        'taskTitle': taskTitle,
      };

  static Session fromJson(Map<String, dynamic> j) => Session(
        id: j['id'] as String,
        endedAt: DateTime.fromMillisecondsSinceEpoch(j['endedAt'] as int),
        minutes: j['minutes'] as int? ?? 0,
        taskId: j['taskId'] as String?,
        taskTitle: j['taskTitle'] as String?,
      );
}

// ───────────────────────── 等级与成就// ───────────────────────── 等级与成就 ─────────────────────────

int xpNeeded(int level) => 100 + (level - 1) * 50;

class LevelInfo {
  const LevelInfo(this.level, this.into, this.need);
  final int level;
  final int into;
  final int need;
}

LevelInfo levelFor(int xp) {
  var level = 1;
  var rest = xp;
  while (rest >= xpNeeded(level)) {
    rest -= xpNeeded(level);
    level++;
  }
  return LevelInfo(level, rest, xpNeeded(level));
}

String levelTitle(int level) {
  if (level < 3) return '专注新手';
  if (level < 6) return '节奏掌控者';
  if (level < 10) return '深度工作者';
  if (level < 15) return '心流大师';
  return '时间领主';
}

class Achievement {
  Achievement(this.id, this.title, this.desc, this.icon, this.test);
  final String id;
  final String title;
  final String desc;
  final IconData icon;
  final bool Function(AppState s) test;
}

final List<Achievement> kAchievements = [
  Achievement('first_pomo', '初次专注', '完成第 1 个番茄钟', Icons.rocket_launch,
      (s) => s.totalPomodoros >= 1),
  Achievement('pomo_10', '渐入佳境', '累计完成 10 个番茄钟',
      Icons.local_fire_department, (s) => s.totalPomodoros >= 10),
  Achievement('pomo_50', '稳定输出', '累计完成 50 个番茄钟', Icons.bolt,
      (s) => s.totalPomodoros >= 50),
  Achievement('pomo_100', '百炼成钢', '累计完成 100 个番茄钟',
      Icons.workspace_premium, (s) => s.totalPomodoros >= 100),
  Achievement('streak_3', '三日连击', '连续 3 天完成专注', Icons.flash_on,
      (s) => s.streak >= 3),
  Achievement('streak_7', '七日不断', '连续 7 天完成专注', Icons.emoji_events,
      (s) => s.streak >= 7),
  Achievement('focus_10h', '十小时', '累计专注 10 小时', Icons.schedule,
      (s) => s.totalFocusSec >= 36000),
  Achievement('task_5', '清单终结者', '累计完成 5 个任务', Icons.task_alt,
      (s) => s.tasksDoneTotal >= 5),
  Achievement('level_5', '五级成长', '达到 Lv.5', Icons.military_tech,
      (s) => levelFor(s.xp).level >= 5),
];

// ───────────────────────── 应用状态 ─────────────────────────

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  AppState._(this._prefs);

  static const _key = 'focusflow_state_v1';
  final SharedPreferences _prefs;

  Settings settings = Settings();
  List<TaskItem> tasks = [];
  Map<String, DayStat> days = {};
  int xp = 0;
  Set<String> unlocked = {};
  List<Moment> moments = [];
  List<Session> sessions = [];

  Phase phase = Phase.focus;
  RunStatus status = RunStatus.idle;
  int totalMs = 25 * 60 * 1000;
  int remainingMs = 25 * 60 * 1000; // 暂停/待机时使用
  int endAtMs = 0; // 运行时使用：目标结束时间
  int focusInCycle = 0;
  String? activeTaskId;

  final ValueNotifier<bool> darkNotifier = ValueNotifier<bool>(true);
  final StreamController<String> _events = StreamController<String>.broadcast();
  Stream<String> get events => _events.stream;

  Timer? _ticker;
  int _lastSec = -1;

  // ───── 云同步状态 ─────
  int dataUpdatedAt = 0; // 数据最后修改时间（不含计时状态）
  String? syncedUid; // 本机上次与哪个账号同步过
  String syncStatus = '';
  StreamSubscription<dynamic>? _authSub;
  Timer? _syncTimer;
  bool _syncing = false;
  bool _pendingResync = false;
  bool _cloudReady = false; // 本次登录是否已完成一次成功的拉取/同步

  // ───── 后台提醒状态 ─────
  bool _inForeground = true;
  bool _askedNotif = false;

  static Future<AppState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = AppState._(prefs);
    s._restore();
    s.initCloud();
    Notifier.cancel(); // 冷启动一定在前台：清掉可能残留的预约
    s._updateSideEffects();
    WidgetsBinding.instance.addObserver(s);
    return s;
  }

  // ───── 持久化 ─────

  void _restore() {
    final raw = _prefs.getString(_key);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      settings = Settings.fromJson(
          (j['settings'] as Map?)?.cast<String, dynamic>() ?? {});
      tasks = ((j['tasks'] as List?) ?? [])
          .map((e) => TaskItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      final d = (j['days'] as Map?) ?? {};
      final loaded = <String, DayStat>{};
      d.forEach((k, v) {
        loaded[k as String] =
            DayStat.fromJson((v as Map).cast<String, dynamic>());
      });
      days = loaded;
      xp = j['xp'] as int? ?? 0;
      moments = ((j['moments'] as List?) ?? [])
          .map((e) => Moment.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      sessions = ((j['sessions'] as List?) ?? [])
          .map((e) => Session.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      unlocked = ((j['unlocked'] as List?) ?? []).map((e) => e as String).toSet();
      final t = (j['timer'] as Map?)?.cast<String, dynamic>() ?? {};
      phase = Phase.values[_ci(t['phase'] as int? ?? 0, 0, 2)];
      status = RunStatus.values[_ci(t['status'] as int? ?? 0, 0, 2)];
      totalMs = t['totalMs'] as int? ?? _phaseMs(phase);
      remainingMs = t['remainingMs'] as int? ?? totalMs;
      endAtMs = t['endAtMs'] as int? ?? 0;
      focusInCycle = t['focusInCycle'] as int? ?? 0;
      activeTaskId = t['activeTaskId'] as String?;
      dataUpdatedAt = j['dataUpdatedAt'] as int? ?? 0;
      syncedUid = j['syncedUid'] as String?;
    } catch (_) {
      // 存档损坏时回到默认状态，避免应用无法启动
      settings = Settings();
      tasks = [];
      days = {};
      xp = 0;
      unlocked = {};
      moments = [];
      sessions = [];
      phase = Phase.focus;
      status = RunStatus.idle;
      totalMs = _phaseMs(phase);
      remainingMs = totalMs;
      endAtMs = 0;
      focusInCycle = 0;
      activeTaskId = null;
    }
    darkNotifier.value = settings.darkMode;
    I18n.apply(settings.language);

    if (status == RunStatus.running) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (endAtMs <= now) {
        _completePhase(restored: true);
      } else {
        _startTicker();
      }
    }
  }

  void _save() {
    final j = <String, dynamic>{
      'settings': settings.toJson(),
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'days': days.map((k, v) => MapEntry(k, v.toJson())),
      'xp': xp,
      'moments': moments.map((m) => m.toJson()).toList(),
      'sessions': sessions.map((s) => s.toJson()).toList(),
      'unlocked': unlocked.toList(),
      'dataUpdatedAt': dataUpdatedAt,
      'syncedUid': syncedUid,
      'timer': {
        'phase': phase.index,
        'status': status.index,
        'totalMs': totalMs,
        'remainingMs': remainingMs,
        'endAtMs': endAtMs,
        'focusInCycle': focusInCycle,
        'activeTaskId': activeTaskId,
      },
    };
    _prefs.setString(_key, jsonEncode(j));
  }

  /// 数据（非计时状态）发生变化：记录修改时间、保存到本机，并安排云同步。
  void _touch() {
    dataUpdatedAt = DateTime.now().millisecondsSinceEpoch;
    _save();
    _scheduleSync();
  }

  Future<void> resetAll() async {
    _stopTicker();
    settings = Settings();
    tasks = [];
    days = {};
    xp = 0;
    unlocked = {};
    moments = [];
    sessions = [];
    phase = Phase.focus;
    status = RunStatus.idle;
    focusInCycle = 0;
    activeTaskId = null;
    totalMs = _phaseMs(phase);
    remainingMs = totalMs;
    endAtMs = 0;
    darkNotifier.value = true;
    I18n.apply(settings.language);
    if (CloudSync.currentUser != null) {
      _touch(); // 已登录：把「清空」也同步到云端
    } else {
      dataUpdatedAt = 0;
      syncedUid = null;
      await _prefs.remove(_key);
    }
    notifyListeners();
  }

  // ───── 计时 ─────

  int _phaseMs(Phase p) {
    final min = p == Phase.focus
        ? settings.focusMin
        : (p == Phase.shortBreak ? settings.shortMin : settings.longMin);
    return min * 60 * 1000;
  }

  int get remaining {
    if (status == RunStatus.running) {
      final r = endAtMs - DateTime.now().millisecondsSinceEpoch;
      return r < 0 ? 0 : r;
    }
    return remainingMs;
  }

  double get progress {
    if (totalMs <= 0) return 0;
    final p = 1 - remaining / totalMs;
    return math.min(1.0, math.max(0.0, p));
  }

  void start() {
    if (status == RunStatus.running) return;
    if (remainingMs <= 0) remainingMs = totalMs;
    endAtMs = DateTime.now().millisecondsSinceEpoch + remainingMs;
    status = RunStatus.running;
    _startTicker();
    _requestNotifPermissionOnce();
    _save();
    notifyListeners();
  }

  void pause() {
    if (status != RunStatus.running) return;
    remainingMs = remaining;
    status = RunStatus.paused;
    _stopTicker();
    _save();
    notifyListeners();
  }

  void resetCurrent() {
    _stopTicker();
    _enter(phase, run: false);
    _save();
    notifyListeners();
  }

  /// 跳过当前阶段：不计入统计，也没有奖励。
  void skip() {
    _stopTicker();
    final next = phase == Phase.focus ? Phase.shortBreak : Phase.focus;
    _enter(next, run: false);
    _save();
    notifyListeners();
  }

  void selectPhase(Phase p) {
    if (status == RunStatus.running) return;
    _enter(p, run: false);
    _save();
    notifyListeners();
  }

  void _enter(Phase next, {required bool run}) {
    phase = next;
    totalMs = _phaseMs(next);
    remainingMs = totalMs;
    _lastSec = -1;
    if (run) {
      status = RunStatus.running;
      endAtMs = DateTime.now().millisecondsSinceEpoch + totalMs;
      _startTicker();
    } else {
      status = RunStatus.idle;
    }
  }

  void _startTicker() {
    _lastSec = -1;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _tick({bool force = false}) {
    if (status != RunStatus.running) {
      _stopTicker();
      return;
    }
    final left = endAtMs - DateTime.now().millisecondsSinceEpoch;
    if (left <= 0) {
      _completePhase();
      return;
    }
    final sec = (left / 1000).ceil();
    if (force || sec != _lastSec) {
      _lastSec = sec;
      notifyListeners();
    }
  }

  void _completePhase({bool restored = false}) {
    _stopTicker();
    final finished = phase;
    final levelBefore = levelFor(xp).level;
    final msgs = <String>[];

    if (finished == Phase.focus) {
      final today = _today();
      today.focusSec += totalMs ~/ 1000;
      today.pomodoros += 1;
      final gain = settings.focusMin * 2;
      xp += gain;
      focusInCycle += 1;
      final t = activeTask;
      if (t != null) {
        t.pomodoros += 1;
        t.focusSec += totalMs ~/ 1000;
      }
      sessions.add(Session(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        endedAt: DateTime.now(),
        minutes: math.max(1, (totalMs / 60000).round()),
        taskId: t?.id,
        taskTitle: t?.title,
      ));
      if (sessions.length > 800) {
        sessions.removeRange(0, sessions.length - 800);
      }
      msgs.add('专注完成！+$gain XP');
    } else {
      msgs.add('休息结束，开始下一个专注吧');
    }

    Phase next;
    if (finished == Phase.focus) {
      if (focusInCycle >= settings.longEvery) {
        next = Phase.longBreak;
        focusInCycle = 0;
      } else {
        next = Phase.shortBreak;
      }
    } else {
      next = Phase.focus;
    }

    _enter(next, run: settings.autoStart && !restored);
    msgs.addAll(_rewardMessages(levelBefore));
    // 后台时由系统通知负责提醒，避免重复；前台时用应用内提示音/振动
    if (!restored && _inForeground) _alert();
    if (!_inForeground && status == RunStatus.running) {
      _scheduleBackgroundNotification();
    }
    if (finished == Phase.focus) {
      _touch();
    } else {
      _save();
    }
    notifyListeners();
    for (final m in msgs) {
      _events.add(m);
    }
  }

  void _requestNotifPermissionOnce() {
    if (_askedNotif) return;
    _askedNotif = true;
    Notifier.requestPermission();
  }

  /// 应用进入后台且计时在运行：预约一条「结束」通知。
  void _scheduleBackgroundNotification() {
    if (status != RunStatus.running) return;
    Notifier.scheduleEnd(
      endAtMs: endAtMs,
      focus: phase == Phase.focus,
      sound: settings.sound,
      vibrate: settings.vibrate,
    );
  }

  void _alert() {
    if (settings.sound) {
      AudioService.chime();
    }
    if (settings.vibrate) {
      HapticFeedback.vibrate();
      Future<void>.delayed(
          const Duration(milliseconds: 450), () => HapticFeedback.vibrate());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _inForeground = true;
      Notifier.cancel(); // 回到前台：取消后台预约，改由应用内处理
      if (status == RunStatus.running) {
        if (endAtMs <= DateTime.now().millisecondsSinceEpoch) {
          // 在后台期间已经结束：补记结果，但不自动开始下一段、也不再响铃
          _completePhase(restored: true);
        } else {
          _tick(force: true);
        }
      }
      _resumeSync();
    } else if (state == AppLifecycleState.paused) {
      _inForeground = false;
      _save();
      _flushSync();
      _scheduleBackgroundNotification();
    }
  }

  // ───── 奖励 ─────

  List<String> _rewardMessages(int levelBefore) {
    final out = <String>[];
    final after = levelFor(xp).level;
    if (after > levelBefore) out.add('升级！当前 Lv.$after');
    for (final a in kAchievements) {
      if (!unlocked.contains(a.id) && a.test(this)) {
        unlocked.add(a.id);
        out.add('解锁成就：${a.title}');
      }
    }
    return out;
  }

  // ───── 统计 ─────

  DayStat _today() => days.putIfAbsent(dayKey(DateTime.now()), () => DayStat());

  DayStat statFor(DateTime d) => days[dayKey(d)] ?? DayStat();

  int get totalPomodoros => days.values.fold(0, (a, b) => a + b.pomodoros);
  int get totalFocusSec => days.values.fold(0, (a, b) => a + b.focusSec);
  int get tasksDoneTotal => tasks.where((t) => t.done).length;
  double get completionRate =>
      tasks.isEmpty ? 0 : tasksDoneTotal / tasks.length;

  int get streak {
    final now = DateTime.now();
    var d = DateTime(now.year, now.month, now.day);
    if (statFor(d).pomodoros == 0) {
      d = DateTime(d.year, d.month, d.day - 1);
    }
    var n = 0;
    while (statFor(d).pomodoros > 0 && n < 3650) {
      n++;
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return n;
  }

  // ───── 任务 ─────

  TaskItem? get activeTask {
    if (activeTaskId == null) return null;
    for (final t in tasks) {
      if (t.id == activeTaskId) return t;
    }
    return null;
  }

  List<TaskItem> get sortedTasks {
    final list = List<TaskItem>.of(tasks);
    list.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      if (a.priority != b.priority) {
        return b.priority.index - a.priority.index;
      }
      final ad = a.due;
      final bd = b.due;
      if (ad != null && bd != null) {
        final c = ad.compareTo(bd);
        if (c != 0) return c;
      } else if (ad != null) {
        return -1;
      } else if (bd != null) {
        return 1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  /// 所有用过的分类标签（去重、排序）。
  List<String> get allTags {
    final set = <String>{};
    for (final t in tasks) {
      final g = t.tag;
      if (g != null && g.isNotEmpty) set.add(g);
    }
    final list = set.toList();
    list.sort();
    return list;
  }

  void addTask(String title, Priority p, {DateTime? due, String? tag}) {
    tasks.add(TaskItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      priority: p,
      due: due,
      tag: (tag == null || tag.isEmpty) ? null : tag,
    ));
    _touch();
    notifyListeners();
  }

  void updateTask(
    TaskItem t, {
    required String title,
    required Priority priority,
    DateTime? due,
    String? tag,
  }) {
    t.title = title;
    t.priority = priority;
    t.due = due;
    t.tag = (tag == null || tag.isEmpty) ? null : tag;
    _touch();
    notifyListeners();
  }

  void toggleTask(TaskItem t) {
    final levelBefore = levelFor(xp).level;
    final msgs = <String>[];
    if (!t.done) {
      t.done = true;
      t.doneAt = DateTime.now();
      _today().tasksDone += 1;
      if (!t.rewarded) {
        t.rewarded = true;
        xp += 20;
        msgs.add('任务完成 +20 XP');
      }
      if (activeTaskId == t.id) activeTaskId = null;
    } else {
      final at = t.doneAt;
      if (at != null) {
        final stat = days[dayKey(at)];
        if (stat != null && stat.tasksDone > 0) stat.tasksDone -= 1;
      }
      t.done = false;
      t.doneAt = null;
    }
    msgs.addAll(_rewardMessages(levelBefore));
    _touch();
    notifyListeners();
    for (final m in msgs) {
      _events.add(m);
    }
  }

  void deleteTask(TaskItem t) {
    tasks.removeWhere((x) => x.id == t.id);
    if (activeTaskId == t.id) activeTaskId = null;
    _touch();
    notifyListeners();
  }

  void setActiveTask(String? id) {
    activeTaskId = id;
    _save();
    notifyListeners();
  }

  // ───── 账号与云同步 ─────

  bool get cloudAvailable => CloudSync.ready;
  String? get userEmail => CloudSync.currentUser?.email;

  void initCloud() {
    if (!CloudSync.ready) return;
    _authSub = CloudSync.authChanges().listen((u) {
      _cloudReady = false;
      if (u == null) {
        syncStatus = '';
      } else {
        syncNow();
      }
      notifyListeners();
    });
  }

  Future<String?> signIn(String email, String password) =>
      CloudSync.run(() => CloudSync.signIn(email, password));

  Future<String?> register(String email, String password) =>
      CloudSync.run(() => CloudSync.register(email, password));

  Future<String?> resetPassword(String email) =>
      CloudSync.run(() => CloudSync.resetPassword(email));

  /// 退出登录：先把数据同步到云端，成功后才清空本机数据。
  Future<String?> signOut() async {
    _syncTimer?.cancel();
    final ok = await _upload();
    if (!ok) return '同步失败，请联网后再退出登录，以免丢失数据';
    final err = await CloudSync.run(() => CloudSync.signOut());
    if (err != null) return err;
    _clearData();
    return null;
  }

  Future<String?> deleteAccount(String password) async {
    _syncTimer?.cancel();
    final err = await CloudSync.run(() => CloudSync.deleteAccount(password));
    if (err != null) return err;
    _clearData();
    return null;
  }

  void _clearData() {
    _stopTicker();
    settings = Settings();
    tasks = [];
    days = {};
    xp = 0;
    unlocked = {};
    moments = [];
    sessions = [];
    activeTaskId = null;
    focusInCycle = 0;
    syncedUid = null;
    dataUpdatedAt = 0;
    syncStatus = '';
    _cloudReady = false;
    darkNotifier.value = true;
    I18n.apply(settings.language);
    _enter(Phase.focus, run: false);
    _save();
    notifyListeners();
  }

  void _scheduleSync() {
    if (CloudSync.currentUser == null) return;
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 3), _runScheduledSync);
  }

  void _runScheduledSync() {
    if (_cloudReady) {
      _upload();
    } else {
      syncNow();
    }
  }

  void _flushSync() {
    if (_syncTimer?.isActive ?? false) {
      _syncTimer!.cancel();
      _runScheduledSync();
    }
  }

  void _resumeSync() {
    if (CloudSync.currentUser != null && !(_syncTimer?.isActive ?? false)) {
      syncNow();
    }
  }

  String _clock() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> _dataJson() => {
        'settings': settings.toJson(),
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'days': days.map((k, v) => MapEntry(k, v.toJson())),
        'xp': xp,
        'unlocked': unlocked.toList(),
        'moments': moments.map((m) => m.toJson()).toList(),
        'sessions': sessions.map((s) => s.toJson()).toList(),
      };

  /// 用云端数据整体替换本机数据（不含计时状态）。
  void _applyData(Map<String, dynamic> j) {
    settings = Settings.fromJson(
        (j['settings'] as Map?)?.cast<String, dynamic>() ?? {});
    tasks = ((j['tasks'] as List?) ?? [])
        .map((e) => TaskItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    final loaded = <String, DayStat>{};
    ((j['days'] as Map?) ?? {}).forEach((k, v) {
      loaded[k as String] =
          DayStat.fromJson((v as Map).cast<String, dynamic>());
    });
    days = loaded;
    xp = j['xp'] as int? ?? 0;
    unlocked =
        ((j['unlocked'] as List?) ?? []).map((e) => e as String).toSet();
    moments = ((j['moments'] as List?) ?? [])
        .map((e) => Moment.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    sessions = ((j['sessions'] as List?) ?? [])
        .map((e) => Session.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    darkNotifier.value = settings.darkMode;
    I18n.apply(settings.language);
    if (activeTaskId != null && activeTask == null) activeTaskId = null;
    if (status == RunStatus.idle) {
      totalMs = _phaseMs(phase);
      remainingMs = totalMs;
    }
  }

  /// 本机首次与某账号同步时：把云端数据合并进本机，不丢任何一边的记录。
  void _mergeData(Map<String, dynamic> j) {
    final byId = <String, TaskItem>{for (final t in tasks) t.id: t};
    for (final e in ((j['tasks'] as List?) ?? [])) {
      final t = TaskItem.fromJson((e as Map).cast<String, dynamic>());
      byId[t.id] = t;
    }
    tasks = byId.values.toList();

    final mById = <String, Moment>{for (final m in moments) m.id: m};
    for (final e in ((j['moments'] as List?) ?? [])) {
      final m = Moment.fromJson((e as Map).cast<String, dynamic>());
      mById[m.id] = m;
    }
    moments = mById.values.toList();

    final sById = <String, Session>{for (final s in sessions) s.id: s};
    for (final e in ((j['sessions'] as List?) ?? [])) {
      final s = Session.fromJson((e as Map).cast<String, dynamic>());
      sById[s.id] = s;
    }
    sessions = sById.values.toList()
      ..sort((a, b) => a.endedAt.compareTo(b.endedAt));
    if (sessions.length > 800) {
      sessions = sessions.sublist(sessions.length - 800);
    }

    ((j['days'] as Map?) ?? {}).forEach((k, v) {
      final key = k as String;
      final c = DayStat.fromJson((v as Map).cast<String, dynamic>());
      final l = days[key];
      if (l == null) {
        days[key] = c;
      } else {
        l.focusSec = math.max(l.focusSec, c.focusSec);
        l.pomodoros = math.max(l.pomodoros, c.pomodoros);
        l.tasksDone = math.max(l.tasksDone, c.tasksDone);
      }
    });

    xp = math.max(xp, j['xp'] as int? ?? 0);
    unlocked.addAll(((j['unlocked'] as List?) ?? []).map((e) => e as String));
    settings = Settings.fromJson(
        (j['settings'] as Map?)?.cast<String, dynamic>() ?? {});
    darkNotifier.value = settings.darkMode;
    I18n.apply(settings.language);
    if (activeTaskId != null && activeTask == null) activeTaskId = null;
  }

  Future<bool> _upload() async {
    final u = CloudSync.currentUser;
    if (u == null) return false;
    try {
      if (dataUpdatedAt == 0) {
        dataUpdatedAt = DateTime.now().millisecondsSinceEpoch;
      }
      await CloudSync.save(u.uid, jsonEncode(_dataJson()), dataUpdatedAt);
      syncedUid = u.uid;
      _cloudReady = true;
      syncStatus = '已同步 ${_clock()}';
      _save();
      notifyListeners();
      return true;
    } catch (_) {
      _cloudReady = false;
      syncStatus = '同步失败，稍后会自动重试';
      notifyListeners();
      return false;
    }
  }

  /// 拉取云端并与本机对比：新的覆盖旧的，首次同步则合并。
  Future<void> syncNow() async {
    final u = CloudSync.currentUser;
    if (u == null) return;
    if (_syncing) {
      _pendingResync = true;
      return;
    }
    _syncing = true;
    syncStatus = '同步中…';
    notifyListeners();
    try {
      final cloud = await CloudSync.load(u.uid);
      if (cloud == null) {
        if (dataUpdatedAt == 0) {
          dataUpdatedAt = DateTime.now().millisecondsSinceEpoch;
        }
        await CloudSync.save(u.uid, jsonEncode(_dataJson()), dataUpdatedAt);
      } else {
        final cloudAt = cloud['updatedAt'] as int? ?? 0;
        final data =
            jsonDecode(cloud['data'] as String) as Map<String, dynamic>;
        if (syncedUid != u.uid) {
          _mergeData(data);
          dataUpdatedAt = DateTime.now().millisecondsSinceEpoch;
          await CloudSync.save(u.uid, jsonEncode(_dataJson()), dataUpdatedAt);
        } else if (cloudAt > dataUpdatedAt) {
          _applyData(data);
          dataUpdatedAt = cloudAt;
        } else if (dataUpdatedAt > cloudAt) {
          await CloudSync.save(u.uid, jsonEncode(_dataJson()), dataUpdatedAt);
        }
      }
      syncedUid = u.uid;
      _cloudReady = true;
      syncStatus = '已同步 ${_clock()}';
      _save();
    } catch (_) {
      _cloudReady = false;
      syncStatus = '同步失败，稍后会自动重试';
    }
    _syncing = false;
    notifyListeners();
    if (_pendingResync) {
      _pendingResync = false;
      _scheduleSync();
    }
  }

  // ───── 纪念日 / 倒数日 ─────

  /// 置顶的在最前；其余未来的（倒数）按最近排前，已过的按最近排前。
  List<Moment> sortedMoments(DateTime now) {
    final list = List<Moment>.of(moments);
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      final ta = momentTarget(a, now);
      final tb = momentTarget(b, now);
      final fa = !ta.isBefore(now);
      final fb = !tb.isBefore(now);
      if (fa != fb) return fa ? -1 : 1;
      return fa ? ta.compareTo(tb) : tb.compareTo(ta);
    });
    return list;
  }

  void addMoment(String title, DateTime time,
      {bool pinned = false, bool yearly = false}) {
    moments.add(Moment(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      time: time,
      pinned: pinned,
      yearly: yearly,
    ));
    _touch();
    notifyListeners();
  }

  void updateMoment(
    Moment m, {
    required String title,
    required DateTime time,
    required bool pinned,
    required bool yearly,
  }) {
    m.title = title;
    m.time = time;
    m.pinned = pinned;
    m.yearly = yearly;
    _touch();
    notifyListeners();
  }

  void togglePin(Moment m) {
    m.pinned = !m.pinned;
    _touch();
    notifyListeners();
  }

  void deleteMoment(Moment m) {
    moments.removeWhere((x) => x.id == m.id);
    _touch();
    notifyListeners();
  }

  // ───── 专注记录 ─────

  /// 按时间从新到旧。
  List<Session> get sessionsNewestFirst {
    final list = List<Session>.of(sessions);
    list.sort((a, b) => b.endedAt.compareTo(a.endedAt));
    return list;
  }

  // ───── 声音与屏幕常亮 ─────

  String? _lastAmbient;

  void _updateSideEffects() {
    final wantAmbient = settings.ambient != 'none' &&
        status == RunStatus.running &&
        (!settings.ambientOnlyFocus || phase == Phase.focus);
    final key = wantAmbient ? '${settings.ambient}@${settings.ambientVolume}' : null;
    if (key != _lastAmbient) {
      _lastAmbient = key;
      AudioService.setAmbient(
          wantAmbient ? settings.ambient : null, settings.ambientVolume / 100.0);
    }
    Wake.set(settings.keepAwake && status == RunStatus.running);
  }

  @override
  void notifyListeners() {
    _updateSideEffects();
    super.notifyListeners();
  }

  // ───── 设置 ─────  // ───── 设置 ─────

  void updateSettings(void Function(Settings s) change) {
    change(settings);
    darkNotifier.value = settings.darkMode;
    I18n.apply(settings.language);
    if (status == RunStatus.idle) {
      totalMs = _phaseMs(phase);
      remainingMs = totalMs;
    }
    _touch();
    notifyListeners();
  }
}
