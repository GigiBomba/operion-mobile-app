import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/invoice.dart';

/// Horizontal status stepper — the §4.5 visual state machine.
///
/// Shows the Gate-31 blueprint subset `draft → finalized → xml_generated →
/// paid` mapped to REAL backend strings, with `cancelled` as a terminal red
/// side-branch. Completed steps are filled with a check; the current step is
/// highlighted; future steps are muted.
class InvoiceStatusStepper extends StatelessWidget {
  const InvoiceStatusStepper({super.key, required this.status});

  final InvoiceStatus status;

  /// Index of [status] in [kStepperStatuses], or `null` when it is not on the
  /// linear path (e.g. `cancelled`).
  static int? stepIndexFor(InvoiceStatus status) {
    final index = kStepperStatuses.indexOf(status);
    return index == -1 ? null : index;
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final currentIndex = stepIndexFor(status);

    if (status == InvoiceStatus.cancelled) {
      return _CancelledBar(loc: loc);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.invoicing_stepperTitle,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (var i = 0; i < kStepperStatuses.length; i++)
              _StepperStep(
                index: i,
                label: _labelFor(kStepperStatuses[i], loc),
                state: _stepState(i, currentIndex),
              ),
          ],
        ),
      ],
    );
  }

  _StepState _stepState(int i, int? currentIndex) {
    if (currentIndex == null) {
      // Off-path statuses (e.g. a defensive legacy parse) render neutral.
      return _StepState.muted;
    }
    if (i < currentIndex) return _StepState.done;
    if (i == currentIndex) return _StepState.current;
    return _StepState.upcoming;
  }

  static String _labelFor(InvoiceStatus s, AppLocalizations loc) =>
      switch (s) {
        InvoiceStatus.draft => loc.invoicing_stepDraft,
        InvoiceStatus.finalized => loc.invoicing_stepFinalized,
        InvoiceStatus.xmlGenerated => loc.invoicing_stepXml,
        InvoiceStatus.paid => loc.invoicing_stepPaid,
        InvoiceStatus.cancelled => loc.invoicing_stepCancelled,
      };
}

class _StepperStep extends StatelessWidget {
  const _StepperStep({
    required this.index,
    required this.label,
    required this.state,
  });

  final int index;
  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final (circleColor, foreground, connectorColor, isLast) = switch (state) {
      _StepState.done => (
          AppColors.success,
          Colors.white,
          AppColors.success,
          index == kStepperStatuses.length - 1,
        ),
      _StepState.current => (
          AppColors.primary,
          Colors.white,
          AppColors.divider,
          index == kStepperStatuses.length - 1,
        ),
      _StepState.upcoming => (
          AppColors.neutralSubtle,
          AppColors.textSecondary,
          AppColors.divider,
          index == kStepperStatuses.length - 1,
        ),
      _StepState.muted => (
          AppColors.neutralSubtle,
          AppColors.textSecondary,
          AppColors.divider,
          index == kStepperStatuses.length - 1,
        ),
    };

    final step = Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: circleColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: state == _StepState.done
          ? const Icon(Icons.check, size: 13, color: Colors.white)
          : Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: foreground,
              ),
            ),
    );

    return Expanded(
      child: Row(
        children: [
          step,
          if (!isLast)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                color: connectorColor,
              ),
            ),
        ],
      ),
    );
  }
}

/// Labels the steps below the circles — rendered as a second Row so tests and
/// users see every step label.
class InvoiceStatusStepperLabels extends StatelessWidget {
  const InvoiceStatusStepperLabels({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Row(
      children: [
        for (var i = 0; i < kStepperStatuses.length; i++)
          Expanded(
            child: Text(
              InvoiceStatusStepper._labelFor(kStepperStatuses[i], loc),
              textAlign: i == 0
                  ? TextAlign.left
                  : i == kStepperStatuses.length - 1
                      ? TextAlign.right
                      : TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textTertiary,
              ),
            ),
          ),
      ],
    );
  }
}

class _CancelledBar extends StatelessWidget {
  const _CancelledBar({required this.loc});

  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.errorSubtle,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Row(
        children: [
          const Icon(Icons.cancel, size: 18, color: AppColors.error),
          const SizedBox(width: AppSpacing.sm),
          Text(
            loc.invoicing_stepCancelled,
            style: const TextStyle(
              color: AppColors.errorText,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

enum _StepState { done, current, upcoming, muted }
