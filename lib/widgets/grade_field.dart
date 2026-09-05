import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Customer/Lead grade -- the tier a customer is placed in from turnover
/// and relationship (backend/app/core/constants.py). Optional everywhere:
/// a record with no grade yet is normal, so the dropdown always offers a
/// "Not set" choice and the badge simply isn't drawn.

/// Fallback list, kept in the same order as the backend (highest first).
/// GET /api/grades/ is the source of truth; this is what's shown until
/// that call returns, and if it fails.
const kGradeFallback = ['Platinum', 'Diamond', 'Gold', 'Silver'];

/// One-time cache of the server's grade list, so form dialogs (which are
/// built synchronously) can read it without awaiting anything. Screens
/// that open a grade form call [ensureLoaded] from initState.
class GradeOptions {
  GradeOptions._();

  static List<String> values = kGradeFallback;
  static bool _loaded = false;

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true; // one attempt per session -- the fallback covers failure
    try {
      final raw = await ApiService.instance.list('/api/grades/');
      final grades = raw.whereType<String>().toList();
      if (grades.isNotEmpty) values = grades;
    } catch (_) {
      // Offline or an older backend: keep kGradeFallback.
    }
  }
}

/// Dropdown for the Lead / Customer forms. [value] is null when the
/// record has no grade, and picking "Not set" clears it back to null.
class GradeDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;

  const GradeDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Grade',
  });

  @override
  Widget build(BuildContext context) {
    // An existing record could carry a grade the server has since dropped;
    // keep it in the list so the dialog doesn't crash on a missing value.
    final options = [
      ...GradeOptions.values,
      if (value != null && !GradeOptions.values.contains(value)) value!,
    ];
    return DropdownButtonFormField<String?>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Not set', style: TextStyle(color: AppColors.muted)),
        ),
        // Each row wears its own grade colour, so the picker previews what
        // the badge will look like on the list.
        ...options.map(
          (g) => DropdownMenuItem<String?>(
            value: g,
            child: Row(
              children: [
                Icon(gradeIcon(g), size: 16, color: gradeColor(g)),
                const SizedBox(width: 8),
                Text(g, style: TextStyle(color: gradeColor(g), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

/// Colour for a grade -- metal and gem tones rather than the status
/// palette, so a grade pill never reads as a document status. Each is
/// dark enough to stay legible as text on its own 12% tint.
Color gradeColor(String grade) {
  switch (grade.toLowerCase()) {
    case 'platinum':
      return const Color(0xFF3E5266); // polished steel -- the top tier, deepest tone
    case 'diamond':
      return const Color(0xFF0B7389); // icy blue
    case 'gold':
      return const Color(0xFF8C620A); // goldenrod
    case 'silver':
      return const Color(0xFF5F6B78); // the lightest of the four, still readable
    default:
      return AppColors.muted;
  }
}

/// A shape per grade as well as a colour, so the tiers are still
/// distinguishable in greyscale or to a colour-blind eye.
IconData gradeIcon(String grade) {
  switch (grade.toLowerCase()) {
    case 'platinum':
      return Icons.workspace_premium;
    case 'diamond':
      return Icons.diamond_outlined;
    case 'gold':
      return Icons.military_tech_outlined;
    case 'silver':
      return Icons.star_outline;
    default:
      return Icons.label_outline;
  }
}

/// Colored pill for the list rows -- same shape as [StatusBadge], but on
/// its own scale so a grade never reads as a status.
class GradeBadge extends StatelessWidget {
  final String grade;
  const GradeBadge({super.key, required this.grade});

  @override
  Widget build(BuildContext context) {
    final color = gradeColor(grade);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(gradeIcon(grade), size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            grade,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
