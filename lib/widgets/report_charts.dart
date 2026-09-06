import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Charts for the report screens.
///
/// Two forms, chosen by the job each does:
///   * a horizontal **bar** list for "compare magnitude" (who is biggest) --
///     one series, so one hue, no legend: the title names it. Horizontal
///     because customer and product names are long.
///   * a **pie** for part-to-whole share, capped at four slices (top three
///     plus "Other"), every slice directly labelled.
///
/// Colours are the validated categorical steps; the stock health pie uses
/// the reserved status colours instead, because those slices *mean*
/// good/warning/critical. Every slice carries a label, so identity is
/// never colour alone -- and the report table underneath is the table
/// view that the sub-3:1 slices oblige.
class ChartSlice {
  final String label;
  final double value;
  const ChartSlice(this.label, this.value);
}

/// Categorical slots 1, 2, 3, 7 -- the four-colour set that clears the
/// all-pairs CVD and normal-vision floors on a white card.
const List<Color> kCategorical = [
  Color(0xFF2A78D6), // blue
  Color(0xFFEB6834), // orange
  Color(0xFF1BAF7A), // aqua
  Color(0xFF4A3AA7), // violet
];

/// Reserved status colours -- only ever for slices that mean a state.
const Map<String, Color> kStatusColors = {
  'ok': Color(0xFF0CA30C),
  'low': Color(0xFFFAB219),
  'out of stock': Color(0xFFD03B3B),
};

/// Single hue for the magnitude bars: more is not a different thing, just more.
const Color kBarHue = Color(0xFF2A78D6);

String _short(double v) {
  if (v.abs() >= 10000000) return '${(v / 10000000).toStringAsFixed(2)} Cr';
  if (v.abs() >= 100000) return '${(v / 100000).toStringAsFixed(2)} L';
  if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
  return v.toStringAsFixed(0);
}

/// Groups rows by [labelKey], sums [valueKey], returns the biggest first.
List<ChartSlice> summarise(
  List<Map<String, dynamic>> rows,
  String labelKey,
  String valueKey, {
  /// Rank by magnitude, keeping negatives in. Off by default: for sales
  /// or outstanding, a non-positive row has nothing to show.
  bool absolute = false,
}) {
  final totals = <String, double>{};
  for (final row in rows) {
    final label = '${row[labelKey] ?? '--'}';
    final raw = row[valueKey];
    final value = raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0;
    if (!absolute && value <= 0) continue;
    totals[label] = (totals[label] ?? 0) + value;
  }
  final slices = totals.entries
      .where((e) => absolute ? e.value != 0 : e.value > 0)
      .map((e) => ChartSlice(e.key, e.value))
      .toList()
    ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
  return slices;
}

/// Keeps the biggest [keep] and folds the rest into one "Other" slice --
/// a pie past ~4 slices stops being readable, and generating more hues to
/// fit them is the thing never to do.
List<ChartSlice> foldTail(List<ChartSlice> slices, {int keep = 3}) {
  if (slices.length <= keep + 1) return slices;
  final head = slices.take(keep).toList();
  final rest = slices.skip(keep).fold<double>(0, (sum, s) => sum + s.value);
  return [...head, ChartSlice('Other (${slices.length - keep})', rest)];
}

class ReportCharts extends StatelessWidget {
  final List<Map<String, dynamic>> rows;

  /// What the bars rank, e.g. customer -> total.
  final String labelKey;
  final String valueKey;
  final String barTitle;

  /// The pie's share, defaulting to the same measure as the bars. When
  /// [statusKey] is set the pie counts rows per state instead, in status
  /// colours; when [groupKey] is set it sums the measure per group
  /// (Income vs Expenses, Assets vs Liabilities vs Equity).
  final String pieTitle;
  final String? statusKey;
  final String? groupKey;

  /// Rank the bars by magnitude and label them with the signed figure.
  /// A Balance Sheet has negative balances that still matter -- an
  /// overdrawn bank is the biggest number on the page.
  final bool absolute;

  /// Money is formatted as currency; counts are not.
  final bool money;

  const ReportCharts({
    super.key,
    required this.rows,
    required this.labelKey,
    required this.valueKey,
    required this.barTitle,
    required this.pieTitle,
    this.statusKey,
    this.groupKey,
    this.absolute = false,
    this.money = true,
  });

  List<ChartSlice> get _bars =>
      summarise(rows, labelKey, valueKey, absolute: absolute).take(6).toList();

  List<ChartSlice> get _pie {
    if (statusKey != null) {
      final counts = <String, double>{};
      for (final row in rows) {
        final key = '${row[statusKey] ?? '--'}';
        counts[key] = (counts[key] ?? 0) + 1;
      }
      return counts.entries.map((e) => ChartSlice(e.key, e.value)).toList()
        ..sort((a, b) => b.value.compareTo(a.value));
    }
    if (groupKey != null) {
      // Sum the measure per group -- "income vs expenses" is about the
      // amounts, not how many accounts each side happens to have.
      return summarise(rows, groupKey!, valueKey, absolute: true);
    }
    return foldTail(summarise(rows, labelKey, valueKey));
  }

  Color _sliceColor(int i, String label) {
    if (statusKey != null) {
      return kStatusColors[label.toLowerCase()] ?? AppColors.muted;
    }
    return kCategorical[i % kCategorical.length];
  }

  String _fmt(double v) => money ? '₹${_short(v)}' : _short(v);

  @override
  Widget build(BuildContext context) {
    final bars = _bars;
    final pie = _pie;
    if (bars.isEmpty && pie.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth >= 860;
        final barCard = _card(barTitle, _BarList(slices: bars, format: _fmt));
        final pieCard = _card(
          pieTitle,
          _Pie(slices: pie, colorOf: _sliceColor, format: statusKey == null ? _fmt : _short),
        );
        if (!side) {
          return Column(children: [barCard, const SizedBox(height: 16), pieCard]);
        }
        // IntrinsicHeight, not CrossAxisAlignment.stretch: the report page
        // scrolls, so the row's height is unbounded and stretch would throw
        // "BoxConstraints forces an infinite height". This sizes both cards
        // to the taller one instead.
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: barCard),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: pieCard),
            ],
          ),
        );
      },
    );
  }

  Widget _card(String title, Widget child) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: AppColors.ink, fontSize: 14)),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      );
}

/// Horizontal bars: thin marks, rounded data ends, no gridlines to shout
/// over them, the value direct-laballed at the end of each row.
class _BarList extends StatelessWidget {
  final List<ChartSlice> slices;
  final String Function(double) format;
  const _BarList({required this.slices, required this.format});

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return const Text('Nothing to chart yet.', style: TextStyle(color: AppColors.muted));
    }
    final max = slices.first.value.abs();
    return Column(
      children: [
        for (final s in slices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                SizedBox(
                  width: 130,
                  child: Text(s.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Tooltip(
                    message: '${s.label}: ${format(s.value)}',
                    // FractionallySizedBox rather than a LayoutBuilder: the
                    // cards are sized with IntrinsicHeight, which cannot
                    // measure through a LayoutBuilder. A floor of 2% keeps
                    // the smallest bar visible instead of vanishing.
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: max <= 0 ? 0.0 : (s.value.abs() / max).clamp(0.02, 1.0),
                        child: Container(
                          height: 12,
                          decoration: const BoxDecoration(
                            color: kBarHue,
                            borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 92,
                  child: Text(format(s.value),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Pie extends StatefulWidget {
  final List<ChartSlice> slices;
  final Color Function(int, String) colorOf;
  final String Function(double) format;
  const _Pie({required this.slices, required this.colorOf, required this.format});

  @override
  State<_Pie> createState() => _PieState();
}

class _PieState extends State<_Pie> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final slices = widget.slices;
    if (slices.isEmpty) {
      return const Text('Nothing to chart yet.', style: TextStyle(color: AppColors.muted));
    }
    // Shares are computed on magnitude -- a negative slice cannot be drawn,
    // and the legend still shows its real signed figure.
    final total = slices.fold<double>(0, (sum, s) => sum + s.value.abs());

    return Column(
      children: [
        SizedBox(
          height: 190,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2, // a surface gap between fills, never touching
              centerSpaceRadius: 42,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) => setState(
                  () => _touched = response?.touchedSection?.touchedSectionIndex ?? -1,
                ),
              ),
              sections: [
                for (var i = 0; i < slices.length; i++)
                  PieChartSectionData(
                    value: slices[i].value.abs(),
                    color: widget.colorOf(i, slices[i].label),
                    radius: _touched == i ? 62 : 56,
                    // Share on the slice; the name sits in the legend, so
                    // no slice depends on colour alone to be identified.
                    title: total == 0
                        ? ''
                        : '${(slices[i].value.abs() / total * 100).toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Legend: always present, values in ink rather than the slice colour.
        for (var i = 0; i < slices.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: widget.colorOf(i, slices[i].label),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(slices[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.ink, fontSize: 12)),
                ),
                Text(widget.format(slices[i].value),
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
      ],
    );
  }
}
