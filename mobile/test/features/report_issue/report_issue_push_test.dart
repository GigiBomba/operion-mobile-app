import 'package:flutter_test/flutter_test.dart';

import 'package:operion_mobile/core/notifications/notification_handler.dart';
import 'package:operion_mobile/core/notifications/notification_router.dart';

void main() {
  group('Support reply push payload', () {
    test('parses type, conversation id and display text', () {
      final push = SupportReplyPushData.tryParse(<String, dynamic>{
        'type': 'support_reply',
        'conversation_id': 'conv-42',
        'title': 'Your Report',
        'message': 'We have an update on your report',
        'message_id': 'm-1',
      });

      expect(push, isNotNull);
      expect(push!.conversationId, equals('conv-42'));
      expect(push.title, equals('Your Report'));
      expect(push.body, equals('We have an update on your report'));
      expect(push.messageId, equals('m-1'));
    });

    test('accepts thread_id as the conversation fallback', () {
      final push = SupportReplyPushData.tryParse(<String, dynamic>{
        'type': 'support_reply',
        'thread_id': 'conv-7',
      });

      expect(push, isNotNull);
      expect(push!.conversationId, equals('conv-7'));
    });

    test('rejects a support reply without a conversation id', () {
      expect(
        SupportReplyPushData.tryParse(<String, dynamic>{
          'type': 'support_reply',
          'message': 'Update',
        }),
        isNull,
      );
    });

    test('ignores other notification types', () {
      expect(
        SupportReplyPushData.tryParse(<String, dynamic>{
          'type': 'alert',
          'alert_id': '7',
        }),
        isNull,
      );
    });
  });

  group('NotificationRouter support route', () {
    test('maps support_reply to the support thread route', () {
      expect(
        NotificationRouter.resolveRoute(<String, dynamic>{
          'type': 'support_reply',
        }),
        equals(NotificationRoute.supportThread),
      );
    });

    test('extracts the conversation id parameter', () {
      final params = NotificationRouter.resolveParams(<String, dynamic>{
        'type': 'support_reply',
        'conversation_id': 'conv-42',
      });

      expect(params, isNotNull);
      expect(params!['conversationId'], equals('conv-42'));
    });

    test('keeps the existing alert/approval routing', () {
      expect(
        NotificationRouter.resolveRoute(<String, dynamic>{'type': 'alert'}),
        equals(NotificationRoute.alertDetail),
      );
      expect(
        NotificationRouter.resolveRoute(<String, dynamic>{'type': 'approval'}),
        equals(NotificationRoute.alertDetail),
      );
      expect(
        AlertPushData.tryParse(<String, dynamic>{
          'type': 'approval',
          'alert_id': '9',
        }),
        isNotNull,
      );
    });
  });

  group('Support reply local-show dedupe key', () {
    test('uses the message id so repeated deliveries are suppressed', () {
      final first = SupportReplyPushData.tryParse(<String, dynamic>{
        'type': 'support_reply',
        'conversation_id': 'conv-1',
        'message_id': 'm-9',
      });
      final second = SupportReplyPushData.tryParse(<String, dynamic>{
        'type': 'support_reply',
        'conversation_id': 'conv-1',
        'message_id': 'm-9',
      });

      expect(first!.messageId, equals(second!.messageId));
    });
  });
}
