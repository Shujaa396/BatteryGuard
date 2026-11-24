class BatteryHealthAssessment {
  const BatteryHealthAssessment({
    required this.fullChargeCapacityMah,
    required this.designCapacityMah,
    required this.healthPercent,
  });

  factory BatteryHealthAssessment.fromCapacities({
    required double? fullChargeCapacityMah,
    required double? designCapacityMah,
  }) {
    if (fullChargeCapacityMah == null ||
        designCapacityMah == null ||
        !fullChargeCapacityMah.isFinite ||
        !designCapacityMah.isFinite ||
        fullChargeCapacityMah <= 0 ||
        designCapacityMah <= 0 ||
        fullChargeCapacityMah > designCapacityMah) {
      return const BatteryHealthAssessment(
        fullChargeCapacityMah: null,
        designCapacityMah: null,
        healthPercent: null,
      );
    }

    return BatteryHealthAssessment(
      fullChargeCapacityMah: fullChargeCapacityMah,
      designCapacityMah: designCapacityMah,
      healthPercent: (fullChargeCapacityMah / designCapacityMah * 100).round(),
    );
  }

  final double? fullChargeCapacityMah;
  final double? designCapacityMah;
  final int? healthPercent;

  int? get degradationPercent =>
      healthPercent == null ? null : 100 - healthPercent!;

  String? get classification {
    final percent = healthPercent;
    if (percent == null) return null;
    if (percent >= 90) return 'Excellent';
    if (percent >= 80) return 'Good';
    if (percent >= 70) return 'Fair';
    return 'Poor';
  }
}
