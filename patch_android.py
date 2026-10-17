"""在 flutter create 生成安卓工程之后运行：补齐 Mino 需要的原生配置。

- 应用名称、权限（联网/通知/精确闹钟/振动）、通知接收器
- minSdk 不低于 23（Firebase 要求）
- 开启 core library desugaring（本地通知插件要求）
- 关闭 R8 代码压缩（避免插件被误删）
- 如果提供了正式签名密钥（环境变量 + android/app/mino-release.jks），则用它签名 release
"""
import os
import pathlib
import re

app = pathlib.Path("android/app")
manifest = app / "src/main/AndroidManifest.xml"
kts = app / "build.gradle.kts"
groovy = app / "build.gradle"

signing = bool(os.environ.get("MINO_KEYSTORE_PASSWORD")) and (app / "mino-release.jks").exists()

PERMISSIONS = """    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" android:maxSdkVersion="32"/>
    <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
"""

RECEIVERS = """        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
"""


def patch_manifest():
    m = manifest.read_text(encoding="utf-8")
    m = m.replace('android:label="mino"', 'android:label="Mino"')
    if "POST_NOTIFICATIONS" not in m:
        m = m.replace("<application", PERMISSIONS + "    <application", 1)
        m = m.replace("</application>", RECEIVERS + "    </application>", 1)
    manifest.write_text(m, encoding="utf-8")
    print("manifest patched")


def insert_in_release(t, kotlin):
    """在 buildTypes 里的 release { 之后插入关闭压缩的配置。"""
    i = t.find("buildTypes")
    if i < 0:
        print("WARN: buildTypes not found")
        return t
    mm = re.compile(r"release\s*\{").search(t, i)
    if not mm:
        print("WARN: release block not found")
        return t
    extra = (
        "\n            isMinifyEnabled = false\n            isShrinkResources = false"
        if kotlin
        else "\n            minifyEnabled false\n            shrinkResources false"
    )
    return t[: mm.end()] + extra + t[mm.end():]


def patch_kts():
    t = kts.read_text(encoding="utf-8")
    t = t.replace("minSdk = flutter.minSdkVersion", "minSdk = maxOf(23, flutter.minSdkVersion)")

    if "isCoreLibraryDesugaringEnabled" not in t:
        t, n = re.subn(
            r"compileOptions\s*\{",
            "compileOptions {\n        isCoreLibraryDesugaringEnabled = true",
            t,
            count=1,
        )
        if n == 0:
            print("WARN: compileOptions not found")
        t += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")\n}\n'

    i = t.find("buildTypes")
    if signing and i >= 0:
        block = (
            "signingConfigs {\n"
            '        create("release") {\n'
            '            storeFile = file("mino-release.jks")\n'
            '            storePassword = System.getenv("MINO_KEYSTORE_PASSWORD")\n'
            '            keyAlias = "mino"\n'
            '            keyPassword = System.getenv("MINO_KEYSTORE_PASSWORD")\n'
            "        }\n"
            "    }\n\n    "
        )
        t = t[:i] + block + t[i:]
        if 'signingConfigs.getByName("debug")' in t:
            t = t.replace('signingConfigs.getByName("debug")', 'signingConfigs.getByName("release")')
        else:
            print("WARN: debug signingConfig line not found; release signing not wired")

    t = insert_in_release(t, kotlin=True)
    kts.write_text(t, encoding="utf-8")
    print("build.gradle.kts patched (release signing: %s)" % signing)


def patch_groovy():
    t = groovy.read_text(encoding="utf-8")
    t = t.replace("minSdkVersion flutter.minSdkVersion", "minSdkVersion Math.max(23, flutter.minSdkVersion)")
    t = t.replace("minSdk = flutter.minSdkVersion", "minSdk = Math.max(23, flutter.minSdkVersion)")

    if "coreLibraryDesugaringEnabled" not in t:
        t, n = re.subn(
            r"compileOptions\s*\{",
            "compileOptions {\n        coreLibraryDesugaringEnabled true",
            t,
            count=1,
        )
        if n == 0:
            print("WARN: compileOptions not found")
        t += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.5'\n}\n"

    i = t.find("buildTypes")
    if signing and i >= 0:
        block = (
            "signingConfigs {\n"
            "        release {\n"
            '            storeFile file("mino-release.jks")\n'
            '            storePassword System.getenv("MINO_KEYSTORE_PASSWORD")\n'
            '            keyAlias "mino"\n'
            '            keyPassword System.getenv("MINO_KEYSTORE_PASSWORD")\n'
            "        }\n"
            "    }\n\n    "
        )
        t = t[:i] + block + t[i:]
        if "signingConfigs.debug" in t:
            t = t.replace("signingConfigs.debug", "signingConfigs.release")
        else:
            print("WARN: debug signingConfig line not found; release signing not wired")

    t = insert_in_release(t, kotlin=False)
    groovy.write_text(t, encoding="utf-8")
    print("build.gradle patched (release signing: %s)" % signing)


patch_manifest()
if kts.exists():
    patch_kts()
elif groovy.exists():
    patch_groovy()
else:
    raise SystemExit("ERROR: no android/app/build.gradle(.kts) found")
