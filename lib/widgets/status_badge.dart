import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Small colored pill used everywhere a document/master status is
/// shown (spec sec. 14: "Use clear status colors and avoid clutter").
class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  Color _color(BuildContext context) {
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
    final color = _color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        status,
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
