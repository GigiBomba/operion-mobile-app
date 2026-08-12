import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Tablet master-detail layout (blueprint §9, width ≥ 600dp).
///
/// Renders a `Row` with a fixed-width list pane (~360dp) containing the
/// [listPane], and a detail pane that fills the remainder showing
/// [detailBuilder] for the currently selected [selectedIndex]. Phone
/// behavior is unchanged — below the breakpoint the caller uses its normal
/// push navigation.
class MasterDetailLayout extends StatelessWidget {
  const MasterDetailLayout({
    super.key,
    required this.selectedIndex,
    required this.listPane,
    required this.detailBuilder,
    this.listPaneWidth = 360,
  });

  /// The currently selected list item index (drives the detail pane).
  final int selectedIndex;

  /// The list-pane content (e.g. the Records grid or MoreHub tile list).
  final Widget listPane;

  /// Builds the detail-pane content for the selected index.
  final Widget Function(BuildContext context, int index) detailBuilder;

  /// Fixed width of the list pane (defaults to ~360dp per §9).
  final double listPaneWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: listPaneWidth,
          child: listPane,
        ),
        Container(width: 1, color: Theme.of(context).colorScheme.outlineVariant),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: detailBuilder(context, selectedIndex)),
      ],
    );
  }
}

/// Whether the current [context] is at or above the tablet breakpoint (600dp).
bool isTabletWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 600;
