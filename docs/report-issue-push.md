# Report an Issue push contract (mobile)

Status: client-side receive/tap path implemented in W9 (blueprint 41.3e).
The backend sender is **out of scope for this change** and is device-gated -
see the verification notes below.

## Payload

FCM **data-only** message, `type=support_reply`:

```json
{
  "type": "support_reply",
  "conversation_id": "conv-abc123",
  "message_id": "support-reply-conv-abc123-0007",
  "title": "Your Report",
  "message": "We have an update on your report"
}
```

| Field | Required | Meaning |
|---|---|---|
| `type` | yes | Must be exactly `support_reply`. Alert/approval handlers ignore this type. |
| `conversation_id` | yes | Thread opened on tap. `conversationId` and `thread_id` are accepted as fallbacks. |
| `message_id` | strongly recommended | Dedupe key for the local display (iOS 18 double-fire guard). Falls back to a hash of the body. |
| `title` / `message` | no | Display copy. When the app is in the foreground the localized Report an Issue strings are used instead. |

The app displays the message through `flutter_local_notifications` on the
`support_updates_channel` (no inline actions). Tapping it:

1. persists nothing - the conversation id is in the notification payload;
2. calls `ReportIssueController.load(conversationId: ...)`;
3. pushes `ReportIssueScreen` (full-screen host) on the root navigator; if the
   navigator is not ready yet (cold start) the push is retried for up to 10
   frames.

FCM notification-type deliveries (not data-only) are also handled on
`FirebaseMessaging.onMessageOpenedApp` and `getInitialMessage` and route
through the same `openSupportThread` helper.

While the app is in the foreground, the push also refreshes the shared
controller so the More-tab badge dot (`reportIssueBadgeProvider`) reflects the
new `requires_reply` state immediately.

## Device-gated / not verified here

- **No backend sender exists yet.** `operion-ops` and the
  `Calculator logistica` backend do not originate a customer-facing support
  reply push. This repository only provides the receive/tap contract above.
- **No Android/iOS device or emulator is available on the W9 host.** The host
  has Windows + Chrome only; the Windows Flutter plugin set does not include
  `firebase_messaging`, and iOS cannot be built on Windows. Real FCM receipt
  and notification-tap evidence therefore remains device-gated.
- `android/app/google-services.json` exists; `ios/Runner/GoogleService-Info.plist`
  does not, so iOS push configuration is also outstanding.
- Automated coverage in this repo verifies payload parsing, router mapping,
  dedupe keys and the thread deep-link controller call - not OS delivery.
