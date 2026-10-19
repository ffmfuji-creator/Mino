import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// 白噪音循环播放 + 结束提示音。所有调用都吞掉异常，音频出问题不影响计时。
class AudioService {
  static AudioPlayer? _ambient;
  static AudioPlayer? _fx;
  static String? _ambientKind;

  static const Map<String, String> _files = {
    'white': 'sounds/white.wav',
    'brown': 'sounds/brown.wav',
    'rain': 'sounds/rain.wav',
  };

  /// kind 为 null 或未知则停止播放；否则循环播放对应声音。
  static Future<void> setAmbient(String? kind, double volume) async {
    if (kIsWeb) return;
    try {
      if (kind == null || !_files.containsKey(kind)) {
        _ambientKind = null;
        await _ambient?.stop();
        return;
      }
      final v = volume < 0 ? 0.0 : (volume > 1 ? 1.0 : volume);
      final p = _ambient ??= AudioPlayer();
      await p.setReleaseMode(ReleaseMode.loop);
      await p.setVolume(v);
      if (_ambientKind != kind) {
        _ambientKind = kind;
        await p.play(AssetSource(_files[kind]!));
      }
    } catch (_) {}
  }

  /// 专注/休息结束的提示音；播放失败时退回系统提示音。
  static Future<void> chime() async {
    try {
      final p = _fx ??= AudioPlayer();
      await p.setVolume(1.0);
      await p.play(AssetSource('sounds/chime.wav'));
    } catch (_) {
      SystemSound.play(SystemSoundType.alert);
    }
  }
}

/// 屏幕常亮开关。
class Wake {
  static bool _on = false;

  static void set(bool on) {
    if (on == _on) return;
    _on = on;
    try {
      (on ? WakelockPlus.enable() : WakelockPlus.disable()).catchError((_) {});
    } catch (_) {}
  }
}
