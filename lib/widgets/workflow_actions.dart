import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// The Draft -> Submitted -> Approved bar shown on every Sales Inquiry,
/// Quotation and Sales Order row.
///
/// The rules live on the server (backend/app/core/workflow.py); this
/// mirrors them so the buttons say what will happen before you press
/// them. A step that isn't available now is shown disabled with a
/// tooltip explaining why, rather than hidden -- the point of the bar is
/// to show where the document sits in the flow.
const String kDraft = 'Draft';
const String kSubmitted = 'Submitted';
const String kApproved = 'Approved';
const String kCancelled = 'Cancelled';

class WorkflowActions extends StatelessWidget {
  /// Collection path of the document, e.g. '/api/quotations/'.
  final String resourcePath;
  final int? id;
  final String status;

  /// Server-set: the document has been moved on to the next step, so its
  /// status can no longer change at all.
  final bool isLocked;

  /// Called after the server accepts a transition, so the list reloads.
  final Future<void> Function() onChanged;
  final void Function(Object error) onError;

  const WorkflowActions({
    super.key,
    required this.resourcePath,
    required this.id,
    required this.status,
    required this.isLocked,
    required this.onChanged,
    required this.onError,
  });

  Future<void> _move(BuildContext context, String next) async {
    try {
      await ApiService.instance.create('$resourcePath$id/status', {'status': next});
      await onChanged();
    } catch (e) {
      onError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLocked) {
      return const Tooltip(
        message: 'Moved on to the next document -- its status is now fixed',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 16, color: AppColors.muted),
            SizedBox(width: 4),
            Text('Locked', style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    final isDraft = status == kDraft;
    final isSubmitted = status == kSubmitted;
    final isClosed = status == kCancelled;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          label: 'Submit',
          icon: Icons.send_outlined,
          enabled: isDraft,
          disabledReason: isClosed ? 'This document was cancelled' : 'Already submitted',
          onPressed: () => _move(context, kSubmitted),
        ),
        const SizedBox(width: 6),
        _StepButton(
          label: 'Approve',
          icon: Icons.verified_outlined,
          enabled: isSubmitted,
          disabledReason: isDraft
              ? 'Submit it first'
              : isClosed
                  ? 'This document was cancelled'
                  : 'Already approved',
          onPressed: () => _move(context, kApproved),
        ),
        const SizedBox(width: 6),
        _StepButton(
          label: 'Cancel',
          icon: Icons.block_outlined,
          enabled: !isClosed,
          danger: true,
          disabledReason: 'Already cancelled',
          onPressed: () => _confirmCancel(context),
        ),
      ],
    );
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this document?'),
        content: const Text(
          'Cancelling is final -- a cancelled document cannot be reopened, edited or moved on. '
          'Raise a new one instead if you need to start again.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel document'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _move(context, kCancelled);
  }
}

class _StepButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final bool danger;
  final String disabledReason;
  final VoidCallback onPressed;

  const _StepButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.disabledReason,
    required this.onPressed,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.rose : AppColors.brand;
    final button = OutlinedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: enabled ? color.withValues(alpha: 0.5) : AppColors.line),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        visualDensity: VisualDensity.compact,
      ),
    );
    return Tooltip(message: enabled ? label : disabledReason, child: button);
  }
}

/// Whether the next document in the chain can be raised from this one --
/// the server refuses anything that isn't Approved.
bool canMoveOn(String status) => status == kApproved;

/// Whether the contents can still be edited (Draft only, and not locked).
bool canEditDocument(String status, bool isLocked) => status == kDraft && !isLocked;
