import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../models/attendance_record.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';

class AttendanceHistoryTab extends StatefulWidget {
  const AttendanceHistoryTab({Key? key}) : super(key: key);

  @override
  _AttendanceHistoryTabState createState() => _AttendanceHistoryTabState();
}

class _AttendanceHistoryTabState extends State<AttendanceHistoryTab> {
  final List<AttendanceRecord> _allRecords = [];
  Map<int, Map<int, Map<int, List<AttendanceRecord>>>> _organizedRecords = {};

  int? _selectedYear;
  int? _selectedMonth;
  String? _selectedStatus;

  bool _showStatistics = true;

  final List<String> _statusOptions = [
    'Tất cả',
    'Đúng giờ',
    'Đi muộn',
    'Vắng mặt',
  ];

  final Color primaryPink = const Color(0xFFFDB5B9);

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('vi_VN');
    _fetchAttendanceRecords();
  }

  void _fetchAttendanceRecords() async {
    try {
      // Giả sử AuthService.getCurrentUser() trả về map có field 'id'
      final userId = AuthService.getCurrentUser()?['id'];
      if (userId == null) return;

      final records = await AttendanceService.fetchAttendanceHistory(
        userId: userId,
        year: _selectedYear,
        month: _selectedMonth,
        status: _selectedStatus,
      );

      setState(() {
        _allRecords.clear();
        _allRecords.addAll(records);
        _organizeData();
      });
    } catch (e) {
      print('Error fetching attendance: $e');
    }
  }

  // @override
  // void initState() {
  //   super.initState();
  //   initializeDateFormatting('vi_VN');
  //   _generateFakeData();
  //   _organizeData();
  // }

  void _generateFakeData() {
    final random = Random();
    final statuses = ['Đúng giờ', 'Đi muộn', 'Vắng mặt'];
    final currentDate = DateTime.now();

    for (int year = currentDate.year - 1; year <= currentDate.year; year++) {
      final endMonth = (year == currentDate.year) ? currentDate.month : 12;

      for (int month = 1; month <= endMonth; month++) {
        final daysInMonth = DateTime(year, month + 1, 0).day;
        final endDay = (year == currentDate.year && month == currentDate.month)
            ? currentDate.day
            : daysInMonth;

        for (int day = 1; day <= endDay; day++) {
          final weekday = DateTime(year, month, day).weekday;
          if (weekday == 6 || weekday == 7) continue;

          _allRecords.add(AttendanceRecord(
            id: _allRecords.length + 1,
            date: DateTime(year, month, day),
            session: 'Sáng',
            checkInTime: DateTime(year, month, day, 7, 30 + random.nextInt(60)),
            checkOutTime:
            DateTime(year, month, day, 11, 30 + random.nextInt(30)),
            status: statuses[random.nextInt(statuses.length)],
          ));

          _allRecords.add(AttendanceRecord(
            id: _allRecords.length + 1,
            date: DateTime(year, month, day),
            session: 'Chiều',
            checkInTime: DateTime(year, month, day, 13, random.nextInt(60)),
            checkOutTime: DateTime(year, month, day, 17, random.nextInt(30)),
            status: statuses[random.nextInt(statuses.length)],
          ));
        }
      }
    }
  }

  void _organizeData() {
    final filteredRecords = _allRecords.where((record) {
      if (_selectedYear != null && record.date.year != _selectedYear) return false;
      if (_selectedMonth != null && record.date.month != _selectedMonth) return false;
      if (_selectedStatus != null &&
          _selectedStatus != 'Tất cả' &&
          record.status != _selectedStatus) return false;
      return true;
    }).toList();

    _organizedRecords = {};

    for (final record in filteredRecords) {
      final year = record.date.year;
      final month = record.date.month;
      final day = record.date.day;

      _organizedRecords[year] ??= {};
      _organizedRecords[year]![month] ??= {};
      _organizedRecords[year]![month]![day] ??= [];
      _organizedRecords[year]![month]![day]!.add(record);
    }

    setState(() {});
  }

  // Thống kê số lượng từng trạng thái
  Map<String, int> _calculateStatistics() {
    final stats = {
      'Tổng ngày': 0,
      'Đúng giờ': 0,
      'Đi muộn': 0,
      'Vắng mặt': 0,
    };

    final filtered = _allRecords.where((record) {
      if (_selectedYear != null && record.date.year != _selectedYear) {
        return false;
      }
      if (_selectedMonth != null && record.date.month != _selectedMonth) {
        return false;
      }
      if (_selectedStatus != null &&
          _selectedStatus != 'Tất cả' &&
          record.status != _selectedStatus) {
        return false;
      }
      return true;
    }).toList();

    // Đếm ngày duy nhất có điểm danh
    final uniqueDays = <String>{};
    for (var record in filtered) {
      uniqueDays.add('${record.date.year}-${record.date.month}-${record.date.day}');
      stats[record.status] = (stats[record.status] ?? 0) + 1;
    }
    stats['Tổng ngày'] = uniqueDays.length;

    return stats;
  }

  List<int> _getRecentHalfYears() {
    final years = _allRecords.map((r) => r.date.year).toSet().toList()..sort();
    if (years.length <= 2) return years; // Nếu dữ liệu ít, trả về hết
    final halfLength = (years.length / 2).ceil();
    return years.sublist(years.length - halfLength);
  }

  @override
  Widget build(BuildContext context) {
    final availableYears = _getRecentHalfYears();

    int totalSessions = 0;
    final statistics = _calculateStatistics();
    Map<String, int> statusCount = {};
    final filteredRecords = _allRecords.where((record) {
      if (_selectedYear != null && record.date.year != _selectedYear) return false;
      if (_selectedMonth != null && record.date.month != _selectedMonth) return false;
      if (_selectedStatus != null &&
          _selectedStatus != 'Tất cả' &&
          record.status != _selectedStatus) return false;
      return true;
    }).toList();

    for (var rec in filteredRecords) {
      totalSessions++;
      statusCount[rec.status] = (statusCount[rec.status] ?? 0) + 1;
    }

    return Scaffold(
      backgroundColor: Colors.white,

      body: Column(
        children: [
          // Nút bật/tắt thống kê
          Container(
            color: primaryPink.withOpacity(0.1),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.insert_chart_outlined, color: primaryPink),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Thống kê điểm danh',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _showStatistics
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: primaryPink,
                    size: 28,
                  ),
                  onPressed: () {
                    setState(() {
                      _showStatistics = !_showStatistics;
                    });
                  },
                )
              ],
            ),
          ),

          // Phần thống kê ẩn/hiện
          if (_showStatistics)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryPink.withOpacity(0.295),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem('Tổng ngày', statistics['Tổng ngày']!, Colors.grey),
                  _statItem('Đúng giờ', statistics['Đúng giờ']!, Colors.green),
                  _statItem('Đi muộn', statistics['Đi muộn']!, Colors.orange),
                  _statItem('Vắng mặt', statistics['Vắng mặt']!, Colors.red),
                ],
              ),
            ),

          // Bộ lọc Năm - Tháng - Trạng thái theo tỉ lệ 1 : 1 : 1.5
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: primaryPink.withOpacity(0.1),
            child: Row(
              children: [
                // Năm
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int?>(
                    decoration: InputDecoration(
                      labelText: 'Năm',
                      labelStyle: TextStyle(color: primaryPink),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryPink),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryPink, width: 2),
                      ),
                    ),
                    dropdownColor: Colors.white,
                    value: _selectedYear,
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Năm'),
                      ),
                      ...availableYears.map(
                            (year) => DropdownMenuItem<int?>(
                          value: year,
                          child: Text(year.toString()),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedYear = value;
                        _selectedMonth = null; // reset tháng khi đổi năm
                      });
                      _organizeData();
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Tháng
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int?>(
                    decoration: InputDecoration(
                      labelText: 'Tháng',
                      labelStyle: TextStyle(color: primaryPink),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryPink),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryPink, width: 2),
                      ),
                    ),
                    dropdownColor: Colors.white,
                    value: _selectedMonth,
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Tháng'),
                      ),
                      ...List.generate(12, (index) => index + 1).map(
                            (month) => DropdownMenuItem<int?>(
                          value: month,
                          child: Text(month.toString()),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedMonth = value;
                      });
                      _organizeData();
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Trạng thái
                Expanded(
                  flex: 3, // Tăng lên 3 cho tỉ lệ 1.5 (1 + 1 + 1.5 = 3.5 => 1:1:1.5 = 2:2:3 nếu nhân 2)
                  child: DropdownButtonFormField<String?>(
                    decoration: InputDecoration(
                      labelText: 'Trạng thái',
                      labelStyle: TextStyle(color: primaryPink),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryPink),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryPink, width: 2),
                      ),
                    ),
                    dropdownColor: Colors.white,
                    value: _selectedStatus ?? 'Tất cả',
                    items: _statusOptions
                        .map(
                          (status) => DropdownMenuItem<String?>(
                        value: status,
                        child: Text(status),
                      ),
                    )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value;
                      });
                      _organizeData();
                    },
                  ),
                ),
              ],
            ),
          ),


          // Danh sách điểm danh
          Expanded(
            child: filteredRecords.isEmpty
                ? Center(
              child: Text(
                'Không có dữ liệu điểm danh',
                style: TextStyle(
                  color: primaryPink,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
                : ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              children: _buildDaysCards(),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Đúng giờ':
        return Colors.green;
      case 'Đi muộn':
        return Colors.orange;
      case 'Vắng mặt':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _statItem(String label, int value, colorText) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: colorText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDaysCards() {
    List<DateTime> allDates = [];
    _organizedRecords.forEach((year, months) {
      months.forEach((month, days) {
        days.forEach((day, _) {
          allDates.add(DateTime(year, month, day));
        });
      });
    });
    allDates.sort((a, b) => b.compareTo(a));

    final dateFormatTitle = DateFormat('EEEE, dd/MM/yyyy', 'vi_VN');
    final timeFormat = DateFormat('HH:mm');

    return allDates.map((date) {
      final year = date.year;
      final month = date.month;
      final day = date.day;
      final records = _organizedRecords[year]![month]![day]!;

      return Card(
        elevation: 3,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          iconColor: primaryPink,
          shape: Border(),
          collapsedShape: Border(),
          collapsedIconColor: primaryPink,
          title: Row(
            children: [
              Icon(Icons.calendar_today, color: primaryPink),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  dateFormatTitle.format(date),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          children: records.map((record) {
            Color statusColor = _getStatusColor(record.status);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Icon(
                    record.session == 'Sáng'
                        ? Icons.wb_sunny
                        : Icons.wb_twilight,
                    color: record.session == 'Sáng'
                        ? Colors.orange
                        : Colors.indigo,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ca ${record.session}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.login, size: 16, color: statusColor),
                            const SizedBox(width: 6),
                            Text(
                              'Giờ vào:',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              timeFormat.format(record.checkInTime),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.logout, size: 16, color: statusColor),
                            const SizedBox(width: 6),
                            Text(
                              'Giờ ra:',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              timeFormat.format(record.checkOutTime),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      record.status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      );
    }).toList();
  }
}


