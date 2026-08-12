import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Action intents ───────────────────────────────────────────────────────

/// Inline notification actions offered on alert-type rich notifications.
///
/// The string values are stable identifiers shared with the OS-level
/// notification action IDs (`flutter_local_notifications` Android action id /
/// iOS `UNNotificationAction` identifier).
enum NotificationActionType {
  /// Approves the alert via `dispatcherEndpoints.approveAction(id)`.
  approve('approve'),

  /// Re-shows the same notification after 15 minutes (bounded — a
  /// snoozed notification is shown without a Snooze action).
  snooze('snooze'),

  /// Opens the alert detail screen (`showsUserInterface: true`).
  view('view'),

  /// No explicit action — the notification body itself was tapped. Keeps the
  /// pre-existing tap → router behaviour (alert/approval → alert detail).
  tap('tap');

  const NotificationActionType(this.id);

  /// Stable identifier used in notification action payloads.
  final String id;

  static NotificationActionType fromId(String? id) {
    return NotificationActionType.values.firstWhere(
      (t) => t.id == id,
      orElse: () => NotificationActionType.tap,
    );
  }
}

/// A user-initiated action on an alert notification.
///
/// Instances are persisted by [NotificationActionStore] so an action tapped
/// while the app is backgrounded / terminated (where a headless isolate has
/// NO access to the encrypted token store and therefore cannot authenticate)
/// can be executed through the normal authenticated flow on the next app
/// launch.
@immutable
class NotificationActionIntent {
  const NotificationActionIntent({
    required this.type,
    required this.alertId,
    this.title,
    this.body,
    required this.createdAt,
  });

  final NotificationActionType type;

  /// The alert id (`alert_id` from the FCM payload / action response).
  final String alertId;

  final String? title;
  final String? body;

  /// When the action was tapped.
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'type': type.id,
    'alert_id': alertId,
    'title': title,
    'body': body,
    'created_at': createdAt.toIso8601String(),
  };

  factory NotificationActionIntent.fromJson(Map<String, dynamic> json) {
    return NotificationActionIntent(
      type: NotificationActionType.fromId(json['type'] as String?),
      alertId: (json['alert_id'] ?? '').toString(),
      title: json['title'] as String?,
      body: json['body'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  @override
  String toString() => 'NotificationActionIntent(${type.id}, alert $alertId)';
}

// ── Store ────────────────────────────────────────────────────────────────

/// Persists [NotificationActionIntent]s in [SharedPreferences].
///
/// Deliberately uses `shared_preferences` — NOT the encrypted
/// `FlutterSecureStorage` used for auth tokens — because intents must be
/// writable from the headless background isolate where the secure storage
/// plugin is unavailable. Intents never contain secrets (only alert ids +
/// display text), so plain preferences are an acceptable persistence layer.
class NotificationActionStore {
  NotificationActionStore({Future<SharedPreferences> Function()? prefs})
      : _prefs = prefs ?? SharedPreferences.getInstance;

  static const String storageKey = 'pending_notification_actions';

  final Future<SharedPreferences> Function() _prefs;

  /// Loads the persisted pending intents (oldest first).
  Future<List<NotificationActionIntent>> loadPending() async {
    final prefs = await _prefs();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => NotificationActionIntent.fromJson(
              Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      developer.log('NotificationActionStore: corrupt payload → $e',
          name: 'Notifications');
      return const [];
    }
  }

  /// Appends [intent] to the persisted queue.
  Future<void> append(NotificationActionIntent intent) async {
    final pending = await loadPending();
    await _save([...pending, intent]);
  }

  /// Replaces the whole queue with [intents].
  Future<void> replaceAll(List<NotificationActionIntent> intents) async {
    await _save(intents);
  }

  /// Clears every persisted intent.
  Future<void> clear() async {
    final prefs = await _prefs();
    await prefs.remove(storageKey);
  }

  Future<void> _save(List<NotificationActionIntent> intents) async {
    final prefs = await _prefs();
    final encoded = jsonEncode(intents.map((i) => i.toJson()).toList());
    await prefs.setString(storageKey, encoded);
  }
}
