import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'report_charts.dart' show kCategorical, kBarHue;

/// Charts for the Sales Projection dashboard.
///
/// The forecast is a sum of three things -- what has been invoiced, what
/// is on order, and the weighted share of what is still quoted -- so the
/// month bars are **stacked in those three parts** rather than drawn as
/// one "projection" block. A manager reading a month that is ahead of
/// target needs to see *why*: 26L of which 18L is banked is a very
/// different month from 26L of which 18L is pipeline.
///
/// The target is a separate thin rod beside each month rather than a
/// fourth stacked segment: it is not part of the total, it is the line
/// the total is judged against.
///
/// Colours are the four validated categorical steps from
/// report_charts.dart, so this screen reads as the same system as the
/// rest of the reporting. Every series is in the legend and every bar
/// carries a tooltip, so nothing depends on colour alone.

/// Actual / Confirmed / Weighted / Target, in that order.
const Color kActualColor = Color(0xFF2A78D6); // blue -- money in the bank
const Color kOrderColor = Color(0xFF1BAF7A); // aqua -- committed, not yet billed
const Color kPipelineColor = Color(0xFFEB6834); // orange -- still only likely
const Color kTargetColor = Color(0xFF79828F); // grey -- the bar to clear, not a value

/// One period's figures, as every chart here consumes them.
class ProjectionPoint {
  final String label;
  final double target;
  final double actual;
  final double confirmedOrders;
  final double weightedPipeline;

  const ProjectionPoint({
    required this.label,
    this.target = 0,
    this.actual = 0,
    this.confirmedOrders = 0,
    this.weightedPipeline = 0,
  });

  double get projected => actual + confirmedOrders + weightedPipeline;

  /// Rows come back from the API as {period, target, actual, ...}.
  factory ProjectionPoint.fromRow(Map<String, dynamic> row, {String labelKey = 'period'}) {
    double num_(String key) {
      final raw = row[key];
      return raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0;
    }

    return ProjectionPoint(
      label: '${row[labelKey] ?? '--'}',
      target: num_('target'),
      actual: num_('actual'),
      confirmedOrders: num_('confirmed_orders'),
      weightedPipeline: num_('weighted_quotations'),
    );
  }
}

/// Indian short form: a forecast is read in lakhs and crores, not in digits.
String shortMoney(double v) {
  final sign = v < 0 ? '-' : '';
  final n = v.abs();
  if (n >= 10000000) return '$sign₹${(n / 10000000).toStringAsFixed(2)} Cr';
  if (n >= 100000) return '$sign₹${(n / 100000).toStringAsFixed(2)} L';
  if (n >= 1000) return '$sign₹${(n / 1000).toStringAsFixed(1)}k';
  return '$sign₹${n.toStringAsFixed(0)}';
}

String shortNumber(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(2);
}

/// Summary-strip entries that are counts, and those that are percentages.
/// Everything else in a projection summary is money.
const Set<String> kCountSummaryKeys = {'Quotations', 'Documents'};
const Set<String> kPercentSummaryKeys = {'Target achievement', 'Average probability'};

/// Formats one summary figure by what the key *means*.
///
/// Deliberately not by the runtime type of the value: compiled to
/// JavaScript, Dart has one number type, so `780000.0 is int` is **true**
/// on the web and a plain type check would print a rupee total as a bare
/// count. The server sends the same JSON to every platform, so the key is
/// the only reliable signal.
String formatSummaryValue(String key, Object? value) {
  if (value == null) return '--';
  final number = value is num ? value.toDouble() : double.tryParse('$value');
  if (number == null) return '$value';
  if (kPercentSummaryKeys.contains(key)) return '${number.toStringAsFixed(1)}%';
  if (kCountSummaryKeys.contains(key)) return number.toStringAsFixed(0);
  return shortMoney(number);
}

/// The card every chart on this screen sits in.
class ChartCard extends StatelessWidget {
  final String title;
  final String? hint;
  final Widget child;

  const ChartCard({super.key, required this.title, this.hint, required this.child});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: AppColors.ink, fontSize: 14)),
              if (hint != null) ...[
                const SizedBox(height: 3),
                Text(hint!, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
              ],
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      );
}

class _LegendKey {
  final String label;
  final Color color;
  const _LegendKey(this.label, this.color);
}

class _Legend extends StatelessWidget {
  final List<_LegendKey> keys;
  const _Legend(this.keys);

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 16,
        runSpacing: 6,
        children: [
          for (final key in keys)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: key.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text(key.label,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.slate)),
              ],
            ),
        ],
      );
}

class _EmptyChart extends StatelessWidget {
  final String message;
  const _EmptyChart(this.message);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
      );
}

// ---------------------------------------------------------------------------
// Actual vs Target vs Projection
// ---------------------------------------------------------------------------

/// Stacked bars per period (actual + orders + weighted pipeline = the
/// projection), with the target as its own thin rod alongside.
class ProjectionBars extends StatelessWidget {
  final List<ProjectionPoint> points;

  /// Tapping a bar opens the period it belongs to.
  final void Function(ProjectionPoint point)? onTap;

  const ProjectionBars({super.key, required this.points, this.onTap});

  @override
  Widget build(BuildContext context) {
    final live = points.where((p) => p.projected != 0 || p.target != 0).toList();
    if (live.isEmpty) {
      return const _EmptyChart('No sales, orders, quotations or targets in this period yet.');
    }

    final ceiling = live
        .map((p) => p.projected > p.target ? p.projected : p.target)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final headroom = ceiling * 1.15;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Legend([
          _LegendKey('Actual sales', kActualColor),
          _LegendKey('Confirmed orders', kOrderColor),
          _LegendKey('Weighted pipeline', kPipelineColor),
          _LegendKey('Target', kTargetColor),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 260,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Bars keep a workable width by scrolling sideways rather
              // than being squeezed to slivers on a narrow screen.
              final needed = live.length * 56.0;
              final chart = SizedBox(
                width: needed > constraints.maxWidth ? needed : constraints.maxWidth,
                child: _barChart(live, headroom),
              );
              return needed > constraints.maxWidth
                  ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: chart)
                  : chart;
            },
          ),
        ),
      ],
    );
  }

  Widget _barChart(List<ProjectionPoint> live, double headroom) => BarChart(
        BarChartData(
          maxY: headroom == 0 ? 1 : headroom,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final point = live[groupIndex];
                final text = rodIndex == 1
                    ? 'Target ${shortMoney(point.target)}'
                    : 'Projected ${shortMoney(point.projected)}\n'
                        'Actual ${shortMoney(point.actual)}\n'
                        'Orders ${shortMoney(point.confirmedOrders)}\n'
                        'Pipeline ${shortMoney(point.weightedPipeline)}';
                return BarTooltipItem(
                  '${point.label}\n',
                  const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
                  children: [
                    TextSpan(
                      text: text,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                );
              },
            ),
            touchCallback: (event, response) {
              if (!event.isInterestedForInteractions || response?.spot == null) return;
              onTap?.call(live[response!.spot!.touchedBarGroupIndex]);
            },
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.lineSoft, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 56,
                getTitlesWidget: (value, meta) => Text(
                  value == 0 ? '' : shortMoney(value),
                  style: const TextStyle(fontSize: 9.5, color: AppColors.muted),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= live.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      // "January 2027" -> "Jan": the axis has no room and
                      // the tooltip carries the full label.
                      live[index].label.split(' ').first.characters.take(3).toString(),
                      style: const TextStyle(fontSize: 10, color: AppColors.slate),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < live.length; i++)
              BarChartGroupData(
                x: i,
                barsSpace: 3,
                barRods: [
                  BarChartRodData(
                    toY: live[i].projected,
                    width: 16,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                    rodStackItems: [
                      BarChartRodStackItem(0, live[i].actual, kActualColor),
                      BarChartRodStackItem(
                        live[i].actual,
                        live[i].actual + live[i].confirmedOrders,
                        kOrderColor,
                      ),
                      BarChartRodStackItem(
                        live[i].actual + live[i].confirmedOrders,
                        live[i].projected,
                        kPipelineColor,
                      ),
                    ],
                  ),
                  BarChartRodData(
                    toY: live[i].target,
                    width: 6,
                    color: kTargetColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                  ),
                ],
              ),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Monthly sales trend
// ---------------------------------------------------------------------------

/// Actual sales month by month -- one line, because a trend is one thing
/// over time, with the projection behind it as a lighter second line so
/// the months still to come are not simply blank.
class TrendLine extends StatelessWidget {
  final List<ProjectionPoint> points;
  const TrendLine({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.every((p) => p.actual == 0 && p.projected == 0)) {
      return const _EmptyChart('Nothing invoiced yet, so there is no trend to draw.');
    }
    final top = points
        .map((p) => p.projected > p.actual ? p.projected : p.actual)
        .fold<double>(0, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Legend([
          _LegendKey('Actual sales', kActualColor),
          _LegendKey('Projection', kPipelineColor),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: top == 0 ? 1 : top * 1.15,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: AppColors.lineSoft, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => [
                    for (final spot in spots)
                      LineTooltipItem(
                        '${points[spot.x.toInt()].label}\n'
                        '${spot.barIndex == 0 ? 'Actual' : 'Projected'} '
                        '${shortMoney(spot.y)}',
                        const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                  ],
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 56,
                    getTitlesWidget: (value, meta) => Text(
                      value == 0 ? '' : shortMoney(value),
                      style: const TextStyle(fontSize: 9.5, color: AppColors.muted),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= points.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          points[index].label.split(' ').first.characters.take(3).toString(),
                          style: const TextStyle(fontSize: 9.5, color: AppColors.slate),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                _line(points.map((p) => p.actual).toList(), kActualColor, filled: true),
                _line(points.map((p) => p.projected).toList(), kPipelineColor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  LineChartBarData _line(List<double> values, Color color, {bool filled = false}) =>
      LineChartBarData(
        spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
        // Straight segments, not a spline: monthly sales are twelve
        // discrete figures, and a curve through them draws values for
        // dates that have none -- and overshoots below zero between a
        // quiet month and a busy one.
        isCurved: false,
        color: color,
        barWidth: 2.4,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
            radius: 2.6,
            color: color,
            strokeWidth: 0,
          ),
        ),
        belowBarData: BarAreaData(
          show: filled,
          color: color.withValues(alpha: 0.10),
        ),
      );
}

// ---------------------------------------------------------------------------
// Achievement
// ---------------------------------------------------------------------------

/// How each period is tracking against its target, as a filled bar per
/// period. The bar is the projection, the notch is the target, and the
/// figure is written out -- a percentage on its own hides whether a
/// month is 130% of a small target or of a real one.
class AchievementBars extends StatelessWidget {
  final List<ProjectionPoint> points;
  const AchievementBars({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final withTargets = points.where((p) => p.target > 0).toList();
    if (withTargets.isEmpty) {
      return const _EmptyChart(
        'No targets set for this period yet.\nSet them from the Targets button above.',
      );
    }

    return Column(
      children: [
        for (final point in withTargets)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: _row(point),
          ),
      ],
    );
  }

  Widget _row(ProjectionPoint point) {
    final ratio = point.projected / point.target;
    final ahead = ratio >= 1;
    final color = ahead ? AppColors.green : (ratio >= 0.8 ? AppColors.amber : AppColors.rose);

    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(point.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.ink, fontWeight: FontWeight.w600, fontSize: 12)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Tooltip(
            message: '${point.label}: projected ${shortMoney(point.projected)} '
                'against a target of ${shortMoney(point.target)}',
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.lineSoft,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                FractionallySizedBox(
                  // Past 100% the bar is full: the overshoot is in the
                  // figure beside it, and a bar cannot draw past its track.
                  widthFactor: ratio.clamp(0.0, 1.0),
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 62,
          child: Text('${(ratio * 100).toStringAsFixed(0)}%',
              textAlign: TextAlign.right,
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Magnitude bars (salesperson / product / category / pipeline band)
// ---------------------------------------------------------------------------

class MagnitudeSlice {
  final String label;
  final double value;

  /// Shown under the value -- "of which 3.2L is pipeline", a count of
  /// quotations, and so on. Optional.
  final String? note;
  const MagnitudeSlice(this.label, this.value, {this.note});
}

/// Horizontal bars for "who/what is biggest". One series, so one hue --
/// more is not a different thing, just more. Horizontal because
/// salesperson and product names are long.
class MagnitudeBars extends StatelessWidget {
  final List<MagnitudeSlice> slices;
  final int max;
  final bool money;
  final String emptyMessage;
  final void Function(MagnitudeSlice slice)? onTap;

  const MagnitudeBars({
    super.key,
    required this.slices,
    this.max = 8,
    this.money = true,
    this.emptyMessage = 'Nothing to chart yet.',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ranked = [...slices.where((s) => s.value > 0)]
      ..sort((a, b) => b.value.compareTo(a.value));
    final shown = ranked.take(max).toList();
    if (shown.isEmpty) return _EmptyChart(emptyMessage);
    final top = shown.first.value;

    return Column(
      children: [
        for (final slice in shown)
          InkWell(
            onTap: onTap == null ? null : () => onTap!(slice),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 128,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(slice.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w600,
                                fontSize: 12)),
                        if (slice.note != null)
                          Text(slice.note!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.muted, fontSize: 10.5)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        // A 2% floor keeps the smallest bar visible rather
                        // than vanishing to nothing.
                        widthFactor: top <= 0 ? 0.0 : (slice.value / top).clamp(0.02, 1.0),
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
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 86,
                    child: Text(money ? shortMoney(slice.value) : shortNumber(slice.value),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Quotation pipeline by probability
// ---------------------------------------------------------------------------

/// Open value against weighted value, band by band. Two bars per band
/// rather than a pie: the point of the chart is the *gap* between what is
/// quoted and what is expected to land, and a pie cannot show that.
class PipelineByProbability extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const PipelineByProbability({super.key, required this.rows});

  double _num(Map<String, dynamic> row, String key) {
    final raw = row[key];
    return raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final live = rows.where((r) => _num(r, 'value') > 0).toList();
    if (live.isEmpty) {
      return const _EmptyChart('No open quotations in this period.');
    }
    final top = live.map((r) => _num(r, 'value')).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Legend([
          _LegendKey('Quoted value', kTargetColor),
          _LegendKey('Weighted (expected)', kPipelineColor),
        ]),
        const SizedBox(height: 14),
        for (final row in live)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 76,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${row['band']}',
                          style: const TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                      Text('${row['quotations']} quote(s)',
                          style: const TextStyle(color: AppColors.muted, fontSize: 10.5)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Tooltip(
                    message: '${row['band']}: ${shortMoney(_num(row, 'value'))} quoted, '
                        '${shortMoney(_num(row, 'weighted'))} expected',
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: (_num(row, 'value') / top).clamp(0.02, 1.0),
                          child: Container(
                            height: 16,
                            decoration: BoxDecoration(
                              color: kTargetColor.withValues(alpha: 0.30),
                              borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(4)),
                            ),
                          ),
                        ),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: (_num(row, 'weighted') / top).clamp(0.0, 1.0),
                          child: Container(
                            height: 16,
                            decoration: const BoxDecoration(
                              color: kPipelineColor,
                              borderRadius: BorderRadius.horizontal(
                                  right: Radius.circular(4)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 86,
                  child: Text(shortMoney(_num(row, 'weighted')),
                      textAlign: TextAlign.right,
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

/// Lays chart cards out side by side on a wide screen and stacked on a
/// narrow one -- the whole dashboard has to work on a phone.
class ChartGrid extends StatelessWidget {
  final List<Widget> children;
  const ChartGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 900) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  children[i],
                ],
              ],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(width: 16),
                  Expanded(child: children[i]),
                ],
              ],
            ),
          );
        },
      );
}

/// Kept so a future chart on this screen picks its colours from the same
/// validated set as the rest of the reporting.
const List<Color> kProjectionCategorical = kCategorical;
