import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_config.dart';

/// Firebase 访问层：登录、注册、云端读写。其余代码不直接接触 Firebase。
class CloudSync {
  static bool ready = false;

  static Future<void> init() async {
    if (!FirebaseConfig.isConfigured) return;
    try {
      await Firebase.initializeApp(options: FirebaseConfig.options);
      ready = true;
    } catch (_) {
      ready = false;
    }
  }

  static User? get currentUser =>
      ready ? FirebaseAuth.instance.currentUser : null;

  static Stream<User?> authChanges() =>
      FirebaseAuth.instance.authStateChanges();

  static DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  // ───── 账号 ─────

  static Future<void> signIn(String email, String password) async {
    await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  static Future<void> register(String email, String password) async {
    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(), password: password);
    try {
      await cred.user?.sendEmailVerification(); // 注册后自动发验证邮件（失败不影响注册）
    } catch (_) {}
  }

  static bool get emailVerified => currentUser?.emailVerified ?? false;

  static Future<void> sendVerification() async {
    await FirebaseAuth.instance.currentUser?.sendEmailVerification();
  }

  static Future<void> reloadUser() async {
    await FirebaseAuth.instance.currentUser?.reload();
  }

  static Future<void> resetPassword(String email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
  }

  static Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  /// 删除账号：先重新验证密码，再删云端数据，最后删账号。
  static Future<void> deleteAccount(String password) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final email = user.email;
    if (email == null) {
      throw FirebaseAuthException(code: 'no-email');
    }
    await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password));
    await _doc(user.uid).delete().timeout(const Duration(seconds: 10));
    await user.delete();
  }

  // ───── 数据 ─────

  static Future<Map<String, dynamic>?> load(String uid) async {
    final snap = await _doc(uid)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 10));
    return snap.data();
  }

  static Future<void> save(String uid, String json, int updatedAt) {
    return _doc(uid)
        .set({'data': json, 'updatedAt': updatedAt}).timeout(
            const Duration(seconds: 10));
  }

  // ───── 错误信息 ─────

  /// 执行一个账号操作，成功返回 null，失败返回中文错误信息。
  static Future<String?> run(Future<void> Function() action) async {
    try {
      await action();
      return null;
    } on FirebaseAuthException catch (e) {
      return _authMessage(e.code);
    } on TimeoutException {
      return '网络超时，请检查网络后重试';
    } catch (e) {
      return '操作失败：$e';
    }
  }

  static String _authMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return '邮箱格式不正确';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return '邮箱或密码不正确';
      case 'email-already-in-use':
        return '这个邮箱已经注册过了，请直接登录';
      case 'weak-password':
        return '密码太简单，请至少 6 位';
      case 'network-request-failed':
        return '网络连接失败，请检查网络';
      case 'too-many-requests':
        return '尝试次数过多，请稍后再试';
      case 'user-disabled':
        return '该账号已被停用';
      case 'requires-recent-login':
        return '请重新登录后再操作';
      case 'operation-not-allowed':
        return '尚未在 Firebase 中启用邮箱登录';
      default:
        return '操作失败（$code）';
    }
  }
}
