# Phase 5A — R8 / ProGuard keep rules.
#
# Quick actions (§9.2): the Android quick-action (app icon shortcut) icons are
# native drawable resources referenced by name from the merged manifest. Keep
# them so the R8 resource shrinker does not strip them from release builds.
-keep class com.operion.operion_mobile.OperionWidgetProvider { *; }
-keep class com.operion.operion_mobile.OperionDriverWidgetProvider { *; }
-keepresources drawable/ic_quick_approve
-keepresources drawable/ic_quick_alerts
-keepresources drawable/ic_quick_scan
