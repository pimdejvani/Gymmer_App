/// Profile → Measures → Log: a blank measurement form. Cancel/Save app bar,
/// a tappable date row (defaults today), an "Add Picture" path card, then the
/// metric fields. Blank fields save as null; the latest entry's values show as
/// hint text (the form itself starts blank).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/media_storage.dart';
import '../../models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class LogMeasurementPage extends StatefulWidget {
  const LogMeasurementPage({super.key, this.latest});

  /// Previous entry, used only for hint text (never prefilled).
  final MeasurementEntry? latest;

  @override
  State<LogMeasurementPage> createState() => _LogMeasurementPageState();
}

class _LogMeasurementPageState extends State<LogMeasurementPage> {
  DateTime _date = DateTime.now();
  final _photoController = TextEditingController();
  late final Map<String, TextEditingController> _controllers = {
    for (final field in measurementFields)
      field.column: TextEditingController(),
  };
  bool _saving = false;

  @override
  void dispose() {
    _photoController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _format(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final rawPhoto = _photoController.text.trim();
    final storedPhoto = rawPhoto.isEmpty
        ? null
        : await copyExerciseMediaIntoAppStorage(
            rawPhoto,
            exerciseName: 'measurement_${_date.toIso8601String()}',
            kind: 'measurement',
          );
    final values = <String, double?>{
      for (final field in measurementFields)
        field.column: double.tryParse(_controllers[field.column]!.text.trim()),
    };
    if (!mounted) return;
    Navigator.of(
      context,
    ).pop(MeasurementEntry.fromColumns(_date, storedPhoto, values));
  }

  @override
  Widget build(BuildContext context) {
    final months = [
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Measurements'),
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        leadingWidth: 88,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving' : 'Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SurfaceCard(
            child: Row(
              children: [
                const Text(
                  'Date',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _pickDate,
                  child: Text(
                    '${_date.day} ${months[_date.month - 1]} ${_date.year}',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            child: TextField(
              controller: _photoController,
              decoration: const InputDecoration(
                labelText: 'Add Picture (image path)',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final field in measurementFields)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: _controllers[field.column],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: '${field.label} (${field.unit})',
                  isDense: true,
                  hintText: widget.latest == null
                      ? null
                      : (field.get(widget.latest!) != null
                            ? _format(field.get(widget.latest!)!)
                            : null),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
