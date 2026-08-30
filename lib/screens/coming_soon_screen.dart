import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Placeholder for modules that land in a later phase (spec sec. 17
/// Development Approach). Keeping the nav item present -- even
/// unimplemented -- means the navigation structure never has to be
/// re-shuffled as phases are completed; screens/*.dart just swap in
/// for these one at a time.
class ComingSoonScreen extends StatelessWidget {
  final String moduleName;
  final String phaseNote;

  const ComingSoonScreen({super.key, required this.moduleName, required this.phaseNote});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppColors.tintedBox(AppColors.amber, radius: 20),
              child: const Icon(Icons.construction_outlined, size: 44, color: AppColors.amber),
            ),
            const SizedBox(height: 20),
            Text(
              moduleName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.brand,
                  ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                phaseNote,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.slate),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
