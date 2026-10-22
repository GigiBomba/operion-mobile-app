import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/report_issue/providers/report_issue_providers.dart';
import '../../features/report_issue/screens/report_issue_screen.dart';
import '../navigation/app_navigator.dart';

/// Deep-links a support-reply push into the Report an Issue thread
/// (blueprint 41.3e).
///
/// The controller starts loading the thread immediately (calling
/// `ReportIssueController.load(conversationId: ...)`), then the full-screen
/// host is pushed. The navigator may not be mounted yet on a cold start, so
/// the push is retried for a bounded number of frames.
Future<void> openSupportThread(
  ProviderContainer container,
  String conversationId,
) async {
  final id = conversationId.trim();
  if (id.isEmpty) return;

  unawaited(
    container
        .read(reportIssueControllerProvider.notifier)
        .load(conversationId: id),
  );

  var attempts = 0;
  void attempt() {
    if (pushOnRootNavigator(ReportIssueScreen(conversationId: id))) return;
    if (attempts++ >= 10) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
  }

  attempt();
}
