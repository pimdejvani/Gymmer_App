/// Body-measurement entry for the Profile → Measures page. One entry per
/// calendar date (re-logging the same date overwrites). Every metric is
/// nullable; the [measurementFields] descriptor list drives the log form,
/// the summary, and SQLite persistence so the field set lives in one place.
library;

class MeasurementEntry {
  MeasurementEntry({
    required this.date,
    this.photoPath,
    this.bodyWeightKg,
    this.waistCm,
    this.bodyFatPct,
    this.leanBodyMassKg,
    this.neckCm,
    this.shoulderCm,
    this.chestCm,
    this.leftBicepCm,
    this.rightBicepCm,
    this.leftForearmCm,
    this.rightForearmCm,
    this.abdomenCm,
    this.hipsCm,
    this.leftThighCm,
    this.rightThighCm,
    this.leftCalfCm,
    this.rightCalfCm,
  });

  /// Builds an entry from a column → value map (used by the store and the
  /// log form). Unknown columns are ignored; missing columns stay null.
  factory MeasurementEntry.fromColumns(
    DateTime date,
    String? photoPath,
    Map<String, double?> values,
  ) {
    return MeasurementEntry(
      date: date,
      photoPath: photoPath,
      bodyWeightKg: values['body_weight_kg'],
      waistCm: values['waist_cm'],
      bodyFatPct: values['body_fat_pct'],
      leanBodyMassKg: values['lean_body_mass_kg'],
      neckCm: values['neck_cm'],
      shoulderCm: values['shoulder_cm'],
      chestCm: values['chest_cm'],
      leftBicepCm: values['left_bicep_cm'],
      rightBicepCm: values['right_bicep_cm'],
      leftForearmCm: values['left_forearm_cm'],
      rightForearmCm: values['right_forearm_cm'],
      abdomenCm: values['abdomen_cm'],
      hipsCm: values['hips_cm'],
      leftThighCm: values['left_thigh_cm'],
      rightThighCm: values['right_thigh_cm'],
      leftCalfCm: values['left_calf_cm'],
      rightCalfCm: values['right_calf_cm'],
    );
  }

  final DateTime date;
  final String? photoPath;
  final double? bodyWeightKg;
  final double? waistCm;
  final double? bodyFatPct;
  final double? leanBodyMassKg;
  final double? neckCm;
  final double? shoulderCm;
  final double? chestCm;
  final double? leftBicepCm;
  final double? rightBicepCm;
  final double? leftForearmCm;
  final double? rightForearmCm;
  final double? abdomenCm;
  final double? hipsCm;
  final double? leftThighCm;
  final double? rightThighCm;
  final double? leftCalfCm;
  final double? rightCalfCm;
}

/// One measurable metric: SQLite column, display label, unit, and a getter.
class MeasurementField {
  const MeasurementField(this.column, this.label, this.unit, this.get);

  final String column;
  final String label;
  final String unit;
  final double? Function(MeasurementEntry) get;
}

/// The metric set, in the order shown on the log form (and the summary).
const measurementFields = <MeasurementField>[
  MeasurementField('body_weight_kg', 'Body Weight', 'kg', _bodyWeightKg),
  MeasurementField('waist_cm', 'Waist', 'cm', _waistCm),
  MeasurementField('body_fat_pct', 'Body Fat', '%', _bodyFatPct),
  MeasurementField(
    'lean_body_mass_kg',
    'Lean Body Mass',
    'kg',
    _leanBodyMassKg,
  ),
  MeasurementField('neck_cm', 'Neck', 'cm', _neckCm),
  MeasurementField('shoulder_cm', 'Shoulder', 'cm', _shoulderCm),
  MeasurementField('chest_cm', 'Chest', 'cm', _chestCm),
  MeasurementField('left_bicep_cm', 'Left Bicep', 'cm', _leftBicepCm),
  MeasurementField('right_bicep_cm', 'Right Bicep', 'cm', _rightBicepCm),
  MeasurementField('left_forearm_cm', 'Left Forearm', 'cm', _leftForearmCm),
  MeasurementField('right_forearm_cm', 'Right Forearm', 'cm', _rightForearmCm),
  MeasurementField('abdomen_cm', 'Abdomen', 'cm', _abdomenCm),
  MeasurementField('hips_cm', 'Hips', 'cm', _hipsCm),
  MeasurementField('left_thigh_cm', 'Left Thigh', 'cm', _leftThighCm),
  MeasurementField('right_thigh_cm', 'Right Thigh', 'cm', _rightThighCm),
  MeasurementField('left_calf_cm', 'Left Calf', 'cm', _leftCalfCm),
  MeasurementField('right_calf_cm', 'Right Calf', 'cm', _rightCalfCm),
];

double? _bodyWeightKg(MeasurementEntry e) => e.bodyWeightKg;
double? _waistCm(MeasurementEntry e) => e.waistCm;
double? _bodyFatPct(MeasurementEntry e) => e.bodyFatPct;
double? _leanBodyMassKg(MeasurementEntry e) => e.leanBodyMassKg;
double? _neckCm(MeasurementEntry e) => e.neckCm;
double? _shoulderCm(MeasurementEntry e) => e.shoulderCm;
double? _chestCm(MeasurementEntry e) => e.chestCm;
double? _leftBicepCm(MeasurementEntry e) => e.leftBicepCm;
double? _rightBicepCm(MeasurementEntry e) => e.rightBicepCm;
double? _leftForearmCm(MeasurementEntry e) => e.leftForearmCm;
double? _rightForearmCm(MeasurementEntry e) => e.rightForearmCm;
double? _abdomenCm(MeasurementEntry e) => e.abdomenCm;
double? _hipsCm(MeasurementEntry e) => e.hipsCm;
double? _leftThighCm(MeasurementEntry e) => e.leftThighCm;
double? _rightThighCm(MeasurementEntry e) => e.rightThighCm;
double? _leftCalfCm(MeasurementEntry e) => e.leftCalfCm;
double? _rightCalfCm(MeasurementEntry e) => e.rightCalfCm;
