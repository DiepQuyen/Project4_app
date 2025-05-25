class AttendanceRecord {
  final DateTime date;
  final DateTime? checkin;
  final DateTime? checkout;
  final String? earlyCheckoutStatus; // 'none', 'pending', 'approved', 'rejected'
  final String? earlyCheckoutReason;

  AttendanceRecord({
    required this.date,
    this.checkin,
    this.checkout,
    this.earlyCheckoutStatus,
    this.earlyCheckoutReason,
  });
}