import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Small colored pill used everywhere a document/master status is
/// shown (spec sec. 14: "Use clear status colors and avoid clutter").
///
/// A dot carries the colour and the label stays near-black, so a row of
/// mixed statuses scans as text with a colour cue rather than as a strip
/// of coloured words.
class StatusBadge extends StatelessWidget {
  final String status;

  /// Renders without the tinted ground -- for placing on an already
  /// tinted or dark surface.
  final bool compact;

  const StatusBadge({super.key, required this.status, this.compact = false});

  static Color colorFor(BuildContext context, String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'approved':
      case 'paid':
      case 'confirmed':
      case 'accepted':
      case 'posted':
      case 'delivered':
      case 'completed':
        return AppColors.green;
      case 'inactive':
      case 'cancelled':
      case 'rejected':
        return AppColors.rose;
      case 'draft':
      case 'pending':
        return AppColors.slate;
      case 'submitted':
        return AppColors.amber;
      case 'partially paid':
      case 'partially delivered':
      case 'in progress':
      case 'sent':
      case 'negotiation':
        return AppColors.amber;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(context, status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 9, vertical: 5),
      decoration: compact
          ? null
          : BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(color: color.withValues(alpha: 0.22)),
            ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
