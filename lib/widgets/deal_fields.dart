import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// The three fields the Sales Projection module needs on a sales
/// document: who owns the deal, which branch it belongs to, and -- on a
/// quotation -- how likely it is to be won.
///
/// The options come from /api/sales-projection/filters rather than from
/// /api/users, because that endpoint is open to anyone holding Sales or
/// Reports, while the user list is admin-only: a sales rep filling in a
/// quotation must be able to see the names in their own team.
///
/// Everything here is optional. A document raised before these fields
/// existed carries none of them, and the forecast reports that work as
/// "Unassigned" rather than guessing -- see
/// backend/app/core/projection.py.
class DealOptions {
  final List<({int id, String name})> salespeople;
  final List<({int id, String name})> warehouses;
  final List<double> probabilities;

  const DealOptions({
    this.salespeople = const [],
    this.warehouses = const [],
    this.probabilities = const [10, 25, 50, 75, 90, 100],
  });

  static DealOptions? _cached;

  /// Loads once per session and hands the same list to every form.
  ///
  /// A failure here is deliberately swallowed into empty lists: these are
  /// optional fields, and a forecast endpoint being unreachable must not
  /// stop a quotation being written.
  static Future<DealOptions> load() async {
    if (_cached != null) return _cached!;
    try {
      final data = await ApiService.instance.getOne('/api/sales-projection/filters');
      List<({int id, String name})> people(String key) =>
          ((data[key] as List<dynamic>?) ?? [])
              .map((e) => (id: e['id'] as int, name: '${e['name']}'))
              .toList();
      _cached = DealOptions(
        salespeople: people('salespeople'),
        warehouses: people('warehouses'),
        probabilities: ((data['probabilities'] as List<dynamic>?) ?? [])
            .map((e) => (e['value'] as num).toDouble())
            .toList(),
      );
    } catch (_) {
      _cached = const DealOptions();
    }
    return _cached!;
  }

  /// Forgets the cached lists -- call after a salesperson or warehouse is added.
  static void invalidate() => _cached = null;
}

/// How likely a quotation is to be won. Only this share of an open quote
/// reaches the projection, so it is described rather than left as a bare
/// percentage.
class ProbabilityField extends StatelessWidget {
  final double value;
  final List<double> options;
  final ValueChanged<double> onChanged;

  const ProbabilityField({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  static const Map<int, String> _meaning = {
    10: 'Early enquiry',
    25: 'Interested',
    50: 'In discussion',
    75: 'Likely to close',
    90: 'Verbally agreed',
    100: 'Committed',
  };

  @override
  Widget build(BuildContext context) {
    final steps = options.isEmpty ? const [10.0, 25.0, 50.0, 75.0, 90.0, 100.0] : options;
    // A value off the ladder (imported, or set before the ladder existed)
    // is shown rather than silently snapped to the nearest step.
    final items = {...steps, value}.toList()..sort();
    return DropdownButtonFormField<double>(
      initialValue: value,
      decoration: const InputDecoration(
        labelText: 'Win probability',
        helperText: 'Only this share of the quote counts towards the sales forecast',
      ),
      items: [
        for (final step in items)
          DropdownMenuItem(
            value: step,
            child: Text(
              _meaning.containsKey(step.round()) && step == step.roundToDouble()
                  ? '${step.round()}%  ·  ${_meaning[step.round()]}'
                  : '${step % 1 == 0 ? step.round() : step}%',
            ),
          ),
      ],
      onChanged: (v) => onChanged(v ?? value),
    );
  }
}

/// A nullable "who / where" dropdown, with an explicit "not set" entry --
/// clearing an owner has to be possible, not just choosing one.
class DealOwnerField extends StatelessWidget {
  final String label;
  final String emptyLabel;
  final int? value;
  final List<({int id, String name})> options;
  final ValueChanged<int?> onChanged;
  final String? helperText;

  const DealOwnerField({
    super.key,
    required this.label,
    required this.emptyLabel,
    required this.value,
    required this.options,
    required this.onChanged,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return TextFormField(
        enabled: false,
        initialValue: emptyLabel,
        decoration: InputDecoration(labelText: label, helperText: helperText),
      );
    }
    // A stale id (the person left, or belongs to another company) would
    // otherwise crash the dropdown on an assertion.
    final known = options.any((o) => o.id == value);
    return DropdownButtonFormField<int?>(
      initialValue: known ? value : null,
      decoration: InputDecoration(labelText: label, helperText: helperText),
      items: [
        DropdownMenuItem<int?>(
          value: null,
          child: Text(emptyLabel, style: const TextStyle(color: AppColors.muted)),
        ),
        for (final option in options)
          DropdownMenuItem<int?>(value: option.id, child: Text(option.name)),
      ],
      onChanged: onChanged,
    );
  }
}
