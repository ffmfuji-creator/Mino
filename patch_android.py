"""在 flutter create 生成安卓工程之后运行：补齐 Mino 需要的原生配置。

- 应用名称、权限（联网/通知/精确闹钟/振动）、通知接收器
- minSdk 不低于 23（Firebase 要求）
- 开启 core library desugaring（本地通知插件要求）
- 关闭 R8 代码压缩（避免插件被误删）
- 如果提供了正式签名密钥（环境变量 + android/app/mino-release.jks），则用它签名 release
- 桌面小组件（显示置顶/最近的一个「日子」）：Kotlin 提供者 + 布局 + 清单注册
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


WIDGET_RECEIVER = """        <receiver android:name=".MinoWidgetProvider" android:exported="true">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data android:name="android.appwidget.provider" android:resource="@xml/mino_widget_info" />
        </receiver>
"""

WIDGET_KT = """package com.mino.mino

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import org.json.JSONObject
import java.util.Calendar
import java.util.Locale
import kotlin.math.abs

/** 桌面小组件：读取应用保存的数据，显示置顶（或最近）的一个「日子」。 */
class MinoWidgetProvider : AppWidgetProvider() {

    private class Item(
        val title: String,
        val timeMs: Long,
        val pinned: Boolean,
        val yearly: Boolean
    )

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context))
        }
    }

    private fun buildViews(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.mino_widget)
        val now = System.currentTimeMillis()
        var english = Locale.getDefault().language != "zh"
        var title = "Mino"
        var daysText = "-"
        var labelText = if (english) "Add a day in the app" else "在应用里添加一个日子"

        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val raw = prefs.getString("flutter.focusflow_state_v1", null)
            if (raw != null) {
                val root = JSONObject(raw)
                val lang = root.optJSONObject("settings")?.optString("language", "zh") ?: "zh"
                english = when (lang) {
                    "en" -> true
                    "zh" -> false
                    else -> Locale.getDefault().language != "zh"
                }

                val items = ArrayList<Item>()
                val arr = root.optJSONArray("moments")
                if (arr != null) {
                    for (i in 0 until arr.length()) {
                        val o = arr.getJSONObject(i)
                        items.add(
                            Item(
                                o.optString("title"),
                                o.optLong("time"),
                                o.optBoolean("pinned", false),
                                o.optBoolean("yearly", false)
                            )
                        )
                    }
                }

                if (items.isNotEmpty()) {
                    val pool = if (items.any { it.pinned }) items.filter { it.pinned } else items
                    val withTarget = pool.map { Pair(it, targetOf(it, now)) }
                    val future = withTarget.filter { it.second >= now }.minByOrNull { it.second }
                    val best = future ?: withTarget.maxByOrNull { it.second }
                    if (best != null) {
                        val diff = best.second - now
                        val days = abs(diff) / 86400000L
                        val isFuture = diff >= 0
                        title = best.first.title
                        daysText = days.toString()
                        labelText = if (english) {
                            if (isFuture) "days left" else "days since"
                        } else {
                            if (isFuture) "天 · 还有" else "天 · 已过"
                        }
                    }
                }
            }
        } catch (e: Exception) {
            // 读取失败时保持默认文字
        }

        views.setTextViewText(R.id.widget_title, title)
        views.setTextViewText(R.id.widget_days, daysText)
        views.setTextViewText(R.id.widget_label, labelText)

        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launch != null) {
            val pi = PendingIntent.getActivity(
                context,
                0,
                launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pi)
        }
        return views
    }

    private fun targetOf(item: Item, now: Long): Long {
        if (!item.yearly) return item.timeMs
        if (item.timeMs > now) return item.timeMs
        val cal = Calendar.getInstance()
        cal.timeInMillis = item.timeMs
        val month = cal.get(Calendar.MONTH)
        val day = cal.get(Calendar.DAY_OF_MONTH)
        val hour = cal.get(Calendar.HOUR_OF_DAY)
        val minute = cal.get(Calendar.MINUTE)
        val nowCal = Calendar.getInstance()
        nowCal.timeInMillis = now
        val year = nowCal.get(Calendar.YEAR)
        var cand = atYear(year, month, day, hour, minute)
        if (cand < now) cand = atYear(year + 1, month, day, hour, minute)
        return cand
    }

    private fun atYear(year: Int, month: Int, day: Int, hour: Int, minute: Int): Long {
        val c = Calendar.getInstance()
        c.clear()
        c.set(Calendar.YEAR, year)
        c.set(Calendar.MONTH, month)
        val maxDay = c.getActualMaximum(Calendar.DAY_OF_MONTH)
        c.set(Calendar.DAY_OF_MONTH, if (day > maxDay) maxDay else day)
        c.set(Calendar.HOUR_OF_DAY, hour)
        c.set(Calendar.MINUTE, minute)
        return c.timeInMillis
    }
}
"""

WIDGET_LAYOUT = """<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/widget_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@drawable/mino_widget_bg"
    android:gravity="center_vertical"
    android:orientation="vertical"
    android:padding="14dp">

    <TextView
        android:id="@+id/widget_title"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:ellipsize="end"
        android:maxLines="1"
        android:textColor="#E5E7EB"
        android:textSize="14sp"
        android:textStyle="bold" />

    <TextView
        android:id="@+id/widget_days"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:maxLines="1"
        android:textColor="#22D3EE"
        android:textSize="40sp"
        android:textStyle="bold" />

    <TextView
        android:id="@+id/widget_label"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:ellipsize="end"
        android:maxLines="1"
        android:textColor="#8A97B5"
        android:textSize="12sp" />
</LinearLayout>
"""

WIDGET_BG = """<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <solid android:color="#0A0E1A" />
    <corners android:radius="20dp" />
    <stroke android:width="1dp" android:color="#1F2B47" />
</shape>
"""

WIDGET_INFO = """<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:initialLayout="@layout/mino_widget"
    android:minHeight="110dp"
    android:minWidth="130dp"
    android:resizeMode="horizontal|vertical"
    android:updatePeriodMillis="1800000"
    android:widgetCategory="home_screen" />
"""


def patch_widget():
    res = app / "src/main/res"
    kt_dir = app / "src/main/kotlin/com/mino/mino"
    kt_dir.mkdir(parents=True, exist_ok=True)
    (kt_dir / "MinoWidgetProvider.kt").write_text(WIDGET_KT, encoding="utf-8")
    for sub, name, body in (
        ("layout", "mino_widget.xml", WIDGET_LAYOUT),
        ("drawable", "mino_widget_bg.xml", WIDGET_BG),
        ("xml", "mino_widget_info.xml", WIDGET_INFO),
    ):
        d = res / sub
        d.mkdir(parents=True, exist_ok=True)
        (d / name).write_text(body, encoding="utf-8")
    m = manifest.read_text(encoding="utf-8")
    if "MinoWidgetProvider" not in m:
        m = m.replace("</application>", WIDGET_RECEIVER + "    </application>", 1)
        manifest.write_text(m, encoding="utf-8")
    print("widget files written")


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
patch_widget()
if kts.exists():
    patch_kts()
elif groovy.exists():
    patch_groovy()
else:
    raise SystemExit("ERROR: no android/app/build.gradle(.kts) found")
