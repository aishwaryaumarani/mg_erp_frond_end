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

  const ComingSoonScreen({
    super.key,
    required this.moduleName,
    required this.phaseNote,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            padding: const EdgeInsets.fromLTRB(32, 34, 32, 34),
            decoration: AppColors.panel(radius: AppRadius.panel, shadow: true),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  alignment: Alignment.center,
                  decoration: AppColors.tintedBox(AppColors.amber,
                      radius: AppRadius.card, border: false),
                  child: const Icon(Icons.construction_outlined,
                      size: 28, color: AppColors.amber),
                ),
                const SizedBox(height: 22),
                Text(
                  moduleName,
                  textAlign: TextAlign.center,
                  style: AppText.serif(fontSize: 22),
                ),
                const SizedBox(height: 10),
                Container(width: 34, height: 2, color: AppColors.gold),
                const SizedBox(height: 16),
                Text(
                  phaseNote,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 22),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Text(
                    'PLANNED FOR A LATER PHASE',
                    style: AppText.overline.copyWith(fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
