/// Profile → Measures: latest values summary over a list of past entries.
/// Swipe-left deletes an entry; the app-bar + opens the log form.
library;

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/profile/trend_line_chart.dart';
import '../../widgets/shared_widgets.dart';
import 'log_measurement_page.dart';

class MeasurementsPage extends StatefulWidget {
  const MeasurementsPage({
    super.key,
    required this.load,
    required this.save,
    required this.delete,
  });

  final Future<List<MeasurementEntry>> Function() load;
  final Future<void> Function(MeasurementEntry entry) save;
  final Future<void> Function(DateTime date) delete;

  @override
  State<MeasurementsPage> createState() => _MeasurementsPageState();
}

class _MeasurementsPageState extends State<MeasurementsPage> {
  late Future<List<MeasurementEntry>> _future;
  MeasurementField _metric = measurementFields.first;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  void _reload() => setState(() {
    _future = widget.load();
  });

  String _formatValue(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

  String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _logNew(MeasurementEntry? latest) async {
    final entry = await Navigator.of(context).push<MeasurementEntry>(
      MaterialPageRoute(builder: (_) => LogMeasurementPage(latest: latest)),
    );
    if (entry == null) return;
    await widget.save(entry);
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Measures'),
        actions: [
          FutureBuilder<List<MeasurementEntry>>(
            future: _future,
            builder: (context, snapshot) => IconButton(
              tooltip: 'Log Measurements',
              icon: const Icon(Icons.add),
              onPressed: () => _logNew(
                (snapshot.data?.isNotEmpty ?? false)
                    ? snapshot.data!.first
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<MeasurementEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (entries.isNotEmpty) _buildTrend(entries),
              if (entries.isNotEmpty) const SizedBox(height: 16),
              if (entries.isNotEmpty) _buildSummary(entries.first),
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text(
                      'No measurements yet.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              for (final entry in entries) _buildEntryRow(entry),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummary(MeasurementEntry latest) {
    final present = [
      for (final field in measurementFields)
        if (field.get(latest) != null) field,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Latest', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (present.isEmpty)
              const Text(
                'No metrics recorded.',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  for (final field in present)
                    Text(
                      '${field.label}: ${_formatValue(field.get(latest)!)}${field.unit == '%' ? '%' : ' ${field.unit}'}',
                      style: kNumericStyle.copyWith(fontSize: 13),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrend(List<MeasurementEntry> entries) {
    final points = [
      for (final entry in entries.reversed)
        if (_metric.get(entry) != null)
          TrendPoint(date: entry.date, value: _metric.get(entry)!),
    ];
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trend', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (points.isEmpty)
            Text(
              'No ${_metric.label.toLowerCase()} entries yet.',
              style: const TextStyle(color: AppColors.textSecondary),
            )
          else
            TrendLineChart(points: points, unit: _metric.unit),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final field in measurementFields) ...[
                  ChoiceChip(
                    label: Text(field.label),
                    selected: _metric == field,
                    onSelected: (_) => setState(() => _metric = field),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryRow(MeasurementEntry entry) {
    final weight = entry.bodyWeightKg;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Slidable(
        key: ValueKey(entry.date),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.3,
          children: [
            SlidableAction(
              onPressed: (_) async {
                await widget.delete(entry.date);
                if (mounted) _reload();
              },
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              icon: Icons.delete_outline,
              label: 'Delete',
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
          ],
        ),
        child: SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(child: Text(_formatDate(entry.date))),
              if (weight != null)
                Text('${_formatValue(weight)}kg', style: kNumericStyle),
              if (entry.photoPath != null) ...[
                const SizedBox(width: 12),
                const Icon(
                  Icons.image,
                  size: 20,
                  color: AppColors.textTertiary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
