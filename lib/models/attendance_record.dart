class AttendanceRecord {
  final int id;
  final DateTime date;
  final String session;
  final DateTime checkInTime;
  final DateTime checkOutTime;
  final String status;

  AttendanceRecord({
    required this.id,
    required this.date,
    required this.session,
    required this.checkInTime,
    required this.checkOutTime,
    required this.status,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'],
      date: DateTime.parse(json['date']),
      session: json['session'],
      checkInTime: DateTime.parse(json['checkInTime']),
      checkOutTime: DateTime.parse(json['checkOutTime']),
      status: json['status'],
    );
  }
}
