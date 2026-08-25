import 'package:flutter/material.dart';

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
            Icon(Icons.construction_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(moduleName, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              phaseNote,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
