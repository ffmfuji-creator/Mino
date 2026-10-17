import 'package:firebase_core/firebase_core.dart';

/// 把 Firebase 控制台里 Android 应用的配置填到下面 4 项。
/// 它们都来自 google-services.json：
///   apiKey            ← client[0].api_key[0].current_key
///   appId             ← client[0].client_info.mobilesdk_app_id
///   messagingSenderId ← project_info.project_number
///   projectId         ← project_info.project_id
/// 这些是公开标识，不是密码；数据安全由 Firestore 安全规则保证。
/// 保持 PASTE 开头则视为未配置：应用仍可正常使用，只是没有登录与云同步。
class FirebaseConfig {
  static const String apiKey = 'AIzaSyDi-tkq_JntvvQPEs9HH-8zdV_4OPWdmU8';
  static const String appId = '1:777644970263:android:f2424c4d14febfab5ca752';
  static const String messagingSenderId = '777644970263';
  static const String projectId = 'mino-56ed5';

  static bool get isConfigured =>
      !apiKey.startsWith('PASTE') &&
      !appId.startsWith('PASTE') &&
      !messagingSenderId.startsWith('PASTE') &&
      !projectId.startsWith('PASTE');

  static const FirebaseOptions options = FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
  );
}
