import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import 'report_issue_sheet.dart';

/// Full-screen host for the Report an Issue flow.
///
/// The More tab opens [ReportIssueSheet] as a bottom sheet (the app's
/// convention for lightweight input, blueprint 41.3e). This page exists for
/// deep links from a support-reply push, where there is no More-tab route to
/// host a sheet and the root navigator must push a route directly.
class ReportIssueScreen extends StatelessWidget {
  const ReportIssueScreen({super.key, this.conversationId});

  /// Thread to open immediately (push deep link).
  final String? conversationId;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(top: media.padding.top + AppSpacing.lg),
          child: ReportIssueSheet(conversationId: conversationId),
        ),
      ),
    );
  }
}
