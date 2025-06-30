import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../services/salary_service.dart';
import '../services/schedule_service.dart';
import 'AttendanceHistoryTab.dart';
import 'account_screen.dart';
import 'login_screen.dart';
import '../services/leave_service.dart';
class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const HomeScreen({required this.user, Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final Color pinkColor = const Color(0xFFFDB5B9);
  final Color mainColor = const Color(0xFFFDB5B9);
  late final ImageProvider _avatarImage;
  bool _imageLoaded = false;
  String? rateAttendance;
  String _selectedView = 'week'; // 'week', 'month', 'year'
  late Future<List<dynamic>> _combinedDataFuture;
  late AnimationController _animController;
  final List<Map<String, dynamic>> _recentActivities = [];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _currentIndex == 0
          ? _buildHomeContent()
          : _currentIndex == 1
          ? _buildAttendanceHistory()
          : _currentIndex == 2
          ? _buildWorkScheduleTab()
          : AccountScreen(
        user: widget.user,
        onLogout: _handleLogout,
      ),
      bottomNavigationBar: SalomonBottomBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            if (_currentIndex == 0) {
              _refreshHomeData(); // Refresh home data when navigating to home tab
            }
          });
        },
        items: [
          SalomonBottomBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            title: const Text('Trang chủ'),
            selectedColor: pinkColor,
          ),
          SalomonBottomBarItem(
            icon: const Icon(Icons.history_outlined),
            activeIcon: const Icon(Icons.history),
            title: const Text('Lịch sử'),
            selectedColor: pinkColor,
          ),
          SalomonBottomBarItem(
            icon: const Icon(Icons.calendar_month_outlined),
            activeIcon: const Icon(Icons.calendar_month),
            title: const Text('Lịch làm'),
            selectedColor: pinkColor,
          ),
          SalomonBottomBarItem(
            icon: _currentIndex == 3 ?
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: pinkColor,
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                backgroundImage: NetworkImage(widget.user['avatar']),
                radius: 10,
              ),
            ) :
            CircleAvatar(
              backgroundImage: NetworkImage(widget.user['avatar']),
              radius: 12,
            ),
            title: const Text("Tài khoản"),
            selectedColor: pinkColor,
          ),
        ],
      ),
    );
  }
  Widget _buildHomeContent() {
    final now = DateTime.now();
    final dateFormat = DateFormat('EEEE, dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(now, dateFormat, timeFormat, mainColor),

          // Today's Work Status Card ---> done
          _buildAttendanceStatusCard(timeFormat),

          // Today's Services Card --> done
          _buildTodayServicesCard(),

          // Estimated Salary Card -> done
          _buildSalarySection(),

          // Summary Cards -> còn phần đúng giờ
          const SizedBox(height: 16),
          _buildSummaryCards(),

          // Weekly Stats -> done
          const SizedBox(height: 16),
          _buildWeeklyStats(),

          // Recent Activities
          const SizedBox(height: 16),
          _buildRecentAttendanceSection(timeFormat, dateFormat),
        ],
      ),
    );
  }


  Widget _buildAttendanceStatusCard(DateFormat timeFormat) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.work_outline, color: pinkColor),
                  const SizedBox(width: 8),
                  const Text(
                    'Trạng thái làm việc',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Status information
              FutureBuilder<Map<String, dynamic>>(
                future: ScheduleService.getTodayStatus(AuthService.getCurrentUser()?['id']),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final data = snapshot.data ?? {'hasShift': false, 'message': 'Đang tải...', 'status': 'Unknown'};
                  final hasShift = data['hasShift'] as bool;

                  if (!hasShift) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.event_busy, color: Colors.grey[500]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              data['message'] as String,
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final schedules = (data['schedules'] as List<dynamic>);
                  return Column(
                    children: schedules.map((schedule) {
                      final shift = schedule['shift'] as String? ?? '';
                      final checkIn = schedule['checkInTime'] as String? ?? '';
                      final checkOut = schedule['checkOutTime'] as String? ?? '';
                      final status = schedule['status'] as String? ?? '';

                      // Status colors and icons
                      Color statusColor;
                      IconData statusIcon;

                      switch (status) {
                        case 'On Time':
                          statusColor = Colors.green;
                          statusIcon = Icons.check_circle;
                          break;
                        case 'Late':
                          statusColor = Colors.orange;
                          statusIcon = Icons.warning;
                          break;
                        case 'Absent':
                          statusColor = Colors.red;
                          statusIcon = Icons.cancel;
                          break;
                        case 'Working':
                          statusColor = Colors.blue;
                          statusIcon = Icons.work;
                          break;
                        default:
                          statusColor = Colors.grey;
                          statusIcon = Icons.schedule;
                      }

                      // Get shift time
                      final shiftTime = RegExp(r'\((.*?)\)').firstMatch(shift)?.group(1) ?? 'Không rõ';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(statusIcon, color: statusColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Ca $shift',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Thời gian: $shiftTime',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                            if (checkIn.isNotEmpty || checkOut.isNotEmpty)
                              const SizedBox(height: 8),
                            if (checkIn.isNotEmpty)
                              Row(
                                children: [
                                  Icon(Icons.login, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Check in: $checkIn',
                                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                  ),
                                ],
                              ),
                            if (checkOut.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.logout, size: 14, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Check out: $checkOut',
                                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildWorkScheduleTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ScheduleService.getUserSchedule(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Lỗi: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
          );
        }

        final schedules = snapshot.data ?? [];

        return _WorkScheduleContent(schedules: schedules);
      },
    );
  }

  Widget _buildTodayServicesCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.spa, color: pinkColor),
                      const SizedBox(width: 8),
                      const Text(
                        'Dịch vụ hôm nay',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: pinkColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Hôm nay',
                      style: TextStyle(
                        color: pinkColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Services by shift
              FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
                future: _getTodayServicesByShift(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(Icons.event_busy, size: 40, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text(
                              'Không có dịch vụ nào hôm nay',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final servicesByShift = snapshot.data!;
                  final shifts = servicesByShift.keys.toList();

                  return Column(
                    children: shifts.map((shift) {
                      final services = servicesByShift[shift]!;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: Colors.grey[50],
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            initiallyExpanded: false,
                            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: shift == 'Sáng'
                                        ? Colors.amber.withOpacity(0.2)
                                        : Colors.indigo.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    shift == 'Sáng' ? Icons.wb_sunny : Icons.nightlight_round,
                                    size: 16,
                                    color: shift == 'Sáng' ? Colors.amber[700] : Colors.indigo,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Ca $shift',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: pinkColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${services.length} dịch vụ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: pinkColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            children: services.map((service) => _buildServiceCard(service)).toList(),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

// Helper method to group services by shift
  Future<Map<String, List<Map<String, dynamic>>>> _getTodayServicesByShift() async {
    try {
      // Gọi API lấy dữ liệu
      final response = await http.get(
        Uri.parse('${OrderService.baseUrl}/api/v1/admin/appointment/today?userId=${AuthService.getCurrentUser()?['id']}'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // Parse dữ liệu JSON
        final data = json.decode(response.body);

        // Khởi tạo kết quả
        final Map<String, List<Map<String, dynamic>>> result = {};

        // Xử lý dữ liệu đã được nhóm theo ca
        data.forEach((shift, services) {
          if (services is List) {
            // Chuyển đổi List động thành List<Map<String, dynamic>>
            result[shift] = List<Map<String, dynamic>>.from(
                services.map((item) {
                  // Chuyển đổi chuỗi datetime thành đối tượng DateTime
                  final service = Map<String, dynamic>.from(item);
                  if (service['startTime'] is String) {
                    service['startTime'] = DateTime.parse(service['startTime']);
                  }
                  if (service['endTime'] is String) {
                    service['endTime'] = DateTime.parse(service['endTime']);
                  }
                  return service;
                })
            );
          }
        });

        return result;
      } else {
        print('Error status code: ${response.statusCode}');
        return {};
      }
    } catch (e) {
      print('Error in _getTodayServicesByShift: $e');
      return {};
    }
  }
  void _refreshHomeData() {
    // Reset any cached data
    setState(() {
      // Force rebuild of the whole screen
      _currentIndex = 0; // Ensure we're on the home tab
      _generateSampleData();
      _getRateAttendance();
      _combinedDataFuture = _fetchCombinedData();
      _buildSalarySection();
    });
  }
  Widget _buildServiceCard(Map<String, dynamic> service) {
    // Status color based on service status
    Color statusColor;
    IconData statusIcon;

    switch (service['status']) {
      case 'Hoàn thành':
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'Đang thực hiện':
      case 'pending':
        statusColor = Colors.blue;
        statusIcon = Icons.pending_actions;
        break;
      case 'Đã hủy':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Show details dialog
          _showServiceDetailsDialog(service);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: pinkColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.spa, color: pinkColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            service['service'],
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(statusIcon, color: statusColor, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          service['status'],
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.person_outline, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          service['customerName'] ?? '',
                          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          service['timeDisplay'],
                          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showServiceDetailsDialog(Map<String, dynamic> service) {
    bool isCompleted = service['status'] == 'Hoàn thành' || service['status'] == 'completed';
    bool isUpdating = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          // Define status color based on service status
          final Color statusColor = isCompleted
              ? Colors.green.shade700
              : Colors.orange.shade700;

          return AlertDialog(
            contentPadding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Container(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header with gradient
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          mainColor.withOpacity(0.9),
                          mainColor.withOpacity(0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.spa, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Chi tiết dịch vụ',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                service['service'] ?? 'N/A',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Status badge
                  Container(
                    color: statusColor.withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isCompleted ? Icons.check_circle : Icons.pending_actions,
                          color: statusColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          service['status'] ?? 'N/A',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildEnhancedDetailRow(
                          'Khách hàng',
                          service['customerName'] ?? 'N/A',
                          Icons.person,
                        ),
                        const SizedBox(height: 16),
                        _buildEnhancedDetailRow(
                          'Thời gian',
                          service['timeDisplay'] ?? 'N/A',
                          Icons.access_time,
                        ),
                        const SizedBox(height: 16),
                        _buildEnhancedDetailRow(
                          'Hoa hồng',
                          NumberFormat.currency(locale: 'vi_VN', symbol: 'VND', decimalDigits: 0)
                              .format(service['commission'] ?? 0),
                          Icons.monetization_on,
                          valueColor: Colors.green.shade800,
                          valueFontWeight: FontWeight.bold,
                        ),
                      ],
                    ),
                  ),

                  // Buttons
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text('Đóng', style: TextStyle(color: Colors.grey.shade600)),
                        ),
                        const SizedBox(width: 12),
                        if (!isCompleted)
                          ElevatedButton(
                            onPressed: isUpdating
                                ? null
                                : () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                                  contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                                  title: Row(
                                    children: [
                                      Icon(Icons.help_outline, color: mainColor),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Xác nhận hoàn thành',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  content: Text(
                                    'Bạn chắc chắn đã hoàn thành dịch vụ này?',
                                    style: TextStyle(fontSize: 15, color: Colors.black87),
                                  ),
                                  actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: Text(
                                        'Hủy',
                                        style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: mainColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: Text(
                                        'Xác nhận',
                                        style: TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm != true) return;

                              setState(() {
                                isUpdating = true;
                              });

                              print(service);
                              final result = await _markServiceAsCompleted(service['id']);

                              Navigator.pop(context);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(
                                        result['success'] ? Icons.check_circle : Icons.error,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(child: Text(result['message'])),
                                    ],
                                  ),
                                  backgroundColor: result['success'] ? Colors.green : Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );

                              if (result['success']) {
                                if (mounted) {
                                  setState(() {
                                    service['status'] = 'Hoàn thành';
                                  });
                                  _refreshHomeData();
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: mainColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                            ),
                            child: isUpdating
                                ? SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_outline, size: 18),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Đánh dấu hoàn thành',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEnhancedDetailRow(String label, String value, IconData icon,
      {Color? valueColor, FontWeight? valueFontWeight}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: mainColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: mainColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: valueFontWeight ?? FontWeight.w500,
                  color: valueColor ?? Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> _markServiceAsCompleted(int serviceId) async {
    try {
      final userId = AuthService.getCurrentUser()?['id'];
      if (userId == null) {
        return {
          'success': false,
          'message': 'Không thể xác định người dùng hiện tại',
        };
      }

      final response = await http.put(
        Uri.parse('${OrderService.baseUrl}/api/v1/admin/appointment/$serviceId/complete'),
        headers: {
          'Content-Type': 'application/json',
          // Add authorization header if needed
        },
        body: jsonEncode({
          'userId': userId,
        }),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Dịch vụ đã được đánh dấu hoàn thành',
        };
      } else {
        return {
          'success': false,
          'message': 'Không thể cập nhật trạng thái: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error marking service as completed: $e');
      return {
        'success': false,
        'message': 'Lỗi: ${e.toString()}',
      };
    }
  }




  @override
  void initState() {
    super.initState();
    _avatarImage = NetworkImage(widget.user['avatar']);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Generate some sample data
    _generateSampleData();
    _getRateAttendance();
    // Load avatar image safely
    _loadAvatarImage();
    _combinedDataFuture = _fetchCombinedData();
  }

  void _loadAvatarImage() {
    _avatarImage.resolve(const ImageConfiguration())
        .addListener(ImageStreamListener((info, _) {
      if (mounted) {
        setState(() => _imageLoaded = true);
      }
    }, onError: (error, _) {
      // Handle image loading error
      print('Error loading avatar: $error');
    }));
  }

  Future<void> _generateSampleData() async {
    try {
      final userId = AuthService.getCurrentUser()?['id'];
      if (userId == null) return;
      final now = DateTime.now();

      // Gọi API thật
      final records = await AttendanceService.fetchAttendanceHistory(
        userId: userId,
        year: now.year,
        month: now.month,
        status: null,
        take: 3,
      );

      print('Fetched ${records.length} attendance records');
      print('records: $records');
      // Gán vào danh sách recent activities (nếu dùng để hiển thị)
      _recentActivities.clear();
      for (var record in records) {
        _recentActivities.add({
          'date': record.date,
          'checkin': record.checkInTime,
          'checkout': record.checkOutTime,
          'isOnTime': record.status.toLowerCase() == 'on_time',
        });
        print('[${record.status}]');  // In thử có khoảng trắng không
        print(record.status.toLowerCase() == 'on_time'); // test

      }
    } catch (e) {
      print('Error fetching attendance: $e');
    }
  }
  Future<void> _getRateAttendance() async {
    try {
      rateAttendance = await AttendanceService.getRateAttendance();
    } catch (e) {
      print('Error fetching attendance: $e');
    }
  }


  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleLogout() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginScreen()),
            (route) => false,
      );
    }
  }




  Widget _buildHeaderSection(DateTime now, DateFormat dateFormat,
      DateFormat timeFormat, Color color) {
    // Get weekday name using DateFormat
    final String weekdayName = getVietnameseWeekday(now.weekday);
    String datePart = DateFormat('dd/MM/yyyy').format(now);

    String fullDateString = '$weekdayName, $datePart';
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color,
            color.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_imageLoaded)
                CircleAvatar(
                  backgroundImage: _avatarImage,
                  radius: 24,
                  backgroundColor: Colors.white,
                )
              else
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, color: color),
                ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Xin chào,',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  Text(
                    widget.user['name'],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${fullDateString}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Giờ hiện tại: ${timeFormat.format(now)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                constraints: const BoxConstraints(maxWidth: 110),
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'ID: ${widget.user["username"]}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
  String getVietnameseWeekday(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Thứ 2';
      case DateTime.tuesday:
        return 'Thứ 3';
      case DateTime.wednesday:
        return 'Thứ 4';
      case DateTime.thursday:
        return 'Thứ 5';
      case DateTime.friday:
        return 'Thứ 6';
      case DateTime.saturday:
        return 'Thứ 7';
      case DateTime.sunday:
        return 'Chủ nhật';
      default:
        return '';
    }
  }


  Widget _buildSummaryCards() {
    return FutureBuilder<Map<String, dynamic>>(
      future: SalaryService.getEstimatedSalary(AuthService.getCurrentUser()?['id']),
      builder: (context, snapshot) {
        String attendanceValue = '0/0';

        if (snapshot.hasData) {
          final workedDays = snapshot.data!['workedDays'] ?? 0;
          final totalWorkdays = snapshot.data!['totalWorkdays'] ?? 0;
          attendanceValue = '$workedDays/$totalWorkdays';
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  icon: Icons.calendar_month,
                  title: 'Làm việc',
                  value: attendanceValue,
                  subtitle: 'ca',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  icon: Icons.watch_later_outlined,
                  title: 'Đúng giờ',
                  value: rateAttendance ?? '',
                  subtitle: 'tỉ lệ',
                  valueColor: Colors.green,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWeeklyStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StatefulBuilder(
            builder: (context, localSetState) {
              final views = ['tuần', 'tháng', 'năm'];
              final viewKeys = ['week', 'month', 'year'];
              final selectedIndex = viewKeys.indexOf(_selectedView);
              final selectedLabel = views[selectedIndex];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Thống kê theo $selectedLabel',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                          child: ToggleButtons(
                            isSelected: List.generate(3, (i) => i == selectedIndex),
                            onPressed: (index) {
                              if (_selectedView != viewKeys[index]) {
                                _selectedView = viewKeys[index];
                                _combinedDataFuture = _fetchCombinedData();
                                localSetState(() {});
                              }
                            },
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.grey[400],
                            selectedColor: Colors.white,
                            fillColor: mainColor.withOpacity(0.9),
                            splashColor: mainColor.withOpacity(0.5),
                            borderWidth: 0,
                            borderColor: Colors.transparent,
                            selectedBorderColor: Colors.transparent,
                            renderBorder: false,
                            constraints: const BoxConstraints(minWidth: 50, minHeight: 16, maxHeight: 30), // đảm bảo nút đủ to
                            children: List.generate(views.length, (index) {
                              final isSelected = index == selectedIndex;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: isSelected ? mainColor.withOpacity(0.9) : Colors.grey.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(0),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  views[index],
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),

                    ],
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<List<dynamic>>(
                    future: _combinedDataFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator()),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('Lỗi: ${snapshot.error}'));
                      }

                      final weekData = snapshot.data![0] as List<Map<String, dynamic>>;
                      final compareMessage = snapshot.data![1] as String;

                      double totalHours = 0;
                      double maxHours = 0;
                      for (var day in weekData) {
                        final hours = (day['totalHours'] as num).toDouble();
                        totalHours += hours;
                        if (hours > maxHours) maxHours = hours;
                      }
                      maxHours = maxHours > 0 ? maxHours : 8;

                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: weekData.map((day) {
                              final double hours = (day['totalHours'] as num).toDouble();
                              final double ratio = maxHours > 0 ? (hours / maxHours) : 0;
                              return _buildStatColumn(day['day'], ratio, hours);
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Text(
                                  'Tổng giờ làm: ${totalHours.toStringAsFixed(1)} giờ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ),
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.trending_up, size: 16, color: Colors.green),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        compareMessage,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.green,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        softWrap: true,
                                        maxLines: null,
                                        overflow: TextOverflow.visible,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }




// Updated to show hours
  Widget _buildStatColumn(String label, double ratio, double hours) {
    final height = ratio > 0 ? 80.0 * ratio : 2.0;

    return Column(
      children: [
        SizedBox(height: 80 - height),
        Container(
          width: 24,
          height: height,
          decoration: BoxDecoration(
            color: pinkColor.withOpacity(0.7),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          hours > 0 ? hours.toString() : '',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Future<List<dynamic>> _fetchCombinedData() async {
    final statsFuture = _fetchWeeklyStats();
    final compareFuture = _fetchWeekComparison();
    return await Future.wait([statsFuture, compareFuture]);
  }


  Future<String> _fetchWeekComparison() async {
    final userId = AuthService.getCurrentUser()?['id'];
    if (userId == null) throw Exception('User ID not found');

    final response = await http.get(
      Uri.parse('${OrderService.baseUrl}/api/v1/admin/attendance/compare/$userId?type=$_selectedView'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception('Lỗi khi lấy dữ liệu so sánh');
    }
  }


  Future<List<Map<String, dynamic>>> _fetchWeeklyStats() async {
    try {
      final userId = AuthService.getCurrentUser()?['id'];
      if (userId == null) throw Exception('User ID not found');

      final response = await http.get(
        Uri.parse('${OrderService.baseUrl}/api/v1/admin/attendance/find-by-user/$userId?type=$_selectedView'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception('Failed to load stats: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
      throw Exception('Failed to load stats: $e');
    }
  }

  // Widget _buildStatColumn(String label, double ratio) {
  //   final height = ratio > 0 ? 80.0 * ratio : 2.0;
  //
  //   return Column(
  //     children: [
  //       SizedBox(height: 80 - height),
  //       Container(
  //         width: 20,
  //         height: height,
  //         decoration: BoxDecoration(
  //           borderRadius: BorderRadius.circular(10),
  //           color: ratio > 0 ? pinkColor : Colors.grey.shade300,
  //         ),
  //       ),
  //       const SizedBox(height: 8),
  //       Text(
  //         label,
  //         style: TextStyle(
  //           fontSize: 12,
  //           color: Colors.grey.shade700,
  //           fontWeight: FontWeight.w500,
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _buildRecentAttendanceSection(DateFormat timeFormat,
      DateFormat dateFormat) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lịch sử điểm danh gần đây',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _currentIndex = 1; // Switch to history tab
                  });
                },
                child: Text(
                  'Xem tất cả',
                  style: TextStyle(
                    color: pinkColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._recentActivities.take(3).map((activity) =>
              _buildAttendanceItem(
                date: dateFormat.format(activity['date']),
                checkin: timeFormat.format(activity['checkin']),
                checkout: timeFormat.format(activity['checkout']),
                status: activity['isOnTime'] ? 'Đúng giờ' : 'Trễ',
                statusColor: activity['isOnTime'] ? Colors.green : Colors
                    .orange,
              )),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    Color? valueColor,
  }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: pinkColor, size: 20),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: valueColor ?? pinkColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceItem({
    required String date,
    required String checkin,
    required String checkout,
    required String status,
    required Color statusColor,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: pinkColor.withOpacity(0.1),
              ),
              child: Icon(Icons.event_available, color: pinkColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Check-in: $checkin · Check-out: $checkout',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildAttendanceHistory() {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Header with gradient
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  pinkColor.withOpacity(0.9),
                  pinkColor.withOpacity(0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lịch sử',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                TabBar(
                  indicatorColor: Colors.black87,
                  indicatorWeight: 3,
                  labelColor: Colors.black87,
                  labelStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelColor: Colors.white,
                  tabs: const [
                    Tab(text: 'Điểm danh'),
                    Tab(text: 'Đơn khách'),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              children: [
                // Attendance History Tab
                _buildAttendanceHistoryTab(),

                // Orders History Tab
                _buildOrdersHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildAttendanceHistoryTab() {
    return const AttendanceHistoryTab();
  }
  String convertToVietnameseDate(String englishDate) {
    // Map of English weekday names to Vietnamese
    final Map<String, String> weekdayMap = {
      'Monday': 'Thứ hai',
      'Tuesday': 'Thứ ba',
      'Wednesday': 'Thứ tư',
      'Thursday': 'Thứ năm',
      'Friday': 'Thứ sáu',
      'Saturday': 'Thứ bảy',
      'Sunday': 'Chủ nhật',
    };

    // Check for each English weekday and replace with Vietnamese equivalent
    for (final entry in weekdayMap.entries) {
      if (englishDate.contains(entry.key)) {
        return englishDate.replaceFirst(entry.key, entry.value);
      }
    }

    return englishDate; // Return original if no match found
  }


  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'on time':
        return Colors.green;
      case 'late':
        return Colors.orange;
      case 'absent':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

// Helper method to organize attendance data by month and day
  Map<String, Map<String, List<Map<String, dynamic>>>> _organizeAttendanceByMonthAndDay(List<Map<String, dynamic>> records) {
    final result = <String, Map<String, List<Map<String, dynamic>>>>{};

    for (var record in records) {
      // Parse date from record - adjust field names based on your API response
      final DateTime date = DateTime.parse(record['date'] ?? record['checkInTime']);
      final String monthKey = DateFormat('MM/yyyy').format(date);
      final String dayKey = DateFormat('yyyy-MM-dd').format(date);

      // Initialize structures if they don't exist
      result.putIfAbsent(monthKey, () => {});
      result[monthKey]!.putIfAbsent(dayKey, () => []);

      // Add the record to the appropriate day
      result[monthKey]![dayKey]!.add(record);
    }

    return result;
  }


// Icon for shift type
 Widget _buildOrdersHistoryTab() {
    return FutureBuilder<Map<String, List<dynamic>>>(
      future: OrderService.getMonthlyHistory(AuthService.getCurrentUser()?['id']),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_toggle_off, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Không có lịch sử đơn hàng',
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }

        final Map<String, List<dynamic>> allHistory = snapshot.data!;
        final List<String> allMonths = allHistory.keys.toList()
          ..sort((a, b) => DateFormat('MM/yyyy').parse(b).compareTo(
              DateFormat('MM/yyyy').parse(a)));

        String? selectedMonth;

        return StatefulBuilder(
          builder: (context, setState) {
            final filteredMonths = selectedMonth == null
                ? allMonths
                : allMonths.where((m) => m == selectedMonth).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: DropdownButtonFormField<String>(
                    value: selectedMonth,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Lọc theo tháng',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Tất cả các tháng'),
                      ),
                      ...allMonths.map(
                            (month) => DropdownMenuItem<String>(
                          value: month,
                          child: Text(month),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedMonth = value;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredMonths.length,
                    itemBuilder: (context, monthIndex) {
                      final month = filteredMonths[monthIndex];
                      final monthData = allHistory[month]!;
                      final monthSummary =
                      monthData.isNotEmpty ? monthData[0] : null;

                      // Nhóm theo ngày và ca
                      Map<String, Map<String, List<dynamic>>> ordersByDateAndShift = {};

                      for (var i = 1; i < monthData.length; i++) {
                        final order = monthData[i];
                        final dateStr = order['dateDisplay'] ?? '';

                        if (dateStr.isEmpty) continue;

                        final orderTime = order['startTime'] as DateTime?;
                        final shift = orderTime == null
                            ? 'Khác'
                            : (orderTime.hour < 12 ? 'Sáng' : 'Chiều');

                        ordersByDateAndShift[dateStr] ??= {};
                        ordersByDateAndShift[dateStr]![shift] ??= [];
                        ordersByDateAndShift[dateStr]![shift]!.add(order);
                      }

                      final sortedDates = ordersByDateAndShift.keys.toList()
                        ..sort((a, b) => DateFormat('dd/MM/yyyy')
                            .parse(b)
                            .compareTo(DateFormat('dd/MM/yyyy').parse(a)));

                      return ExpansionTile(
                        initiallyExpanded: monthIndex == 0,
                        backgroundColor: Colors.grey[50],
                        collapsedBackgroundColor: Colors.grey[50],
                        collapsedShape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        title: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: mainColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                month,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: mainColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (monthSummary != null) ...[
                              Icon(Icons.paid, size: 18, color: Colors.green[700]),
                              const SizedBox(width: 4),
                              Text(
                                NumberFormat.currency(
                                  locale: 'vi_VN',
                                  symbol: 'VND',
                                  decimalDigits: 0,
                                ).format(monthSummary['totalCommission'] ?? 0),
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          '${monthSummary?['totalOrders'] ?? 0} đơn hàng',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                        children: [
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: sortedDates.length,
                            itemBuilder: (context, dateIndex) {
                              final date = sortedDates[dateIndex];
                              final shiftsMap = ordersByDateAndShift[date]!;

                              final DateTime parsedDate =
                              DateFormat('dd/MM/yyyy').parse(date);
                              final dayOfWeek =
                              DateFormat('EEEE', 'vi_VN').format(parsedDate);

                              return Padding(
                                padding: const EdgeInsets.only(
                                    left: 8, right: 8, bottom: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius:
                                            BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            date.split('/').take(2).join('/'),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          dayOfWeek,
                                          style: TextStyle(
                                            color: Colors.black87,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    ...shiftsMap.entries.map((entry) {
                                      final shift = entry.key;
                                      final orders = entry.value;

                                      return ExpansionTile(
                                        initiallyExpanded: true,
                                        title: Row(
                                          children: [
                                            Icon(
                                              shift == 'Sáng'
                                                  ? Icons.wb_sunny
                                                  : Icons.wb_twilight,
                                              size: 18,
                                              color: shift == 'Sáng'
                                                  ? Colors.orange
                                                  : Colors.indigo,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              shift,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '(${orders.length} đơn)',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                        children: orders.map<Widget>((order) {
                                          final service = order['service'] ?? 'Dịch vụ';
                                          final timeDisplay =
                                              order['timeDisplay'] ?? '';
                                          final commission =
                                              order['commission'] ?? 0;
                                          final status = order['status'] ?? '';

                                          return Card(
                                            margin: const EdgeInsets.symmetric(vertical: 8),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                              side: BorderSide(color: Colors.grey.shade200),
                                            ),
                                            color: const Color(0xFFFFF5F7),
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(16),
                                              onTap: () {
                                                // TODO: mở chi tiết đơn hàng
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.all(16),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    /// Hàng đầu: Tên dịch vụ + Trạng thái
                                                    Row(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        const Icon(Icons.design_services, size: 20, color: Colors.pink),
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: Text(
                                                            service,
                                                            style: const TextStyle(
                                                              fontWeight: FontWeight.w600,
                                                              fontSize: 16,
                                                            ),
                                                          ),
                                                        ),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: _getStatusColor(status).withOpacity(0.9),
                                                            borderRadius: BorderRadius.circular(20),
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                Icons.check_circle,
                                                                size: 14,
                                                                color: Colors.white,
                                                              ),
                                                              const SizedBox(width: 4),
                                                              Text(
                                                                status,
                                                                style: const TextStyle(
                                                                  color: Colors.white,
                                                                  fontSize: 12,
                                                                  fontWeight: FontWeight.w500,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),

                                                    const SizedBox(height: 12),

                                                    /// Hàng thứ 2: Thời gian
                                                    Row(
                                                      children: [
                                                        const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          timeDisplay,
                                                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                                                        ),
                                                      ],
                                                    ),

                                                    const SizedBox(height: 12),
                                                    const Divider(height: 1),
                                                    const SizedBox(height: 12),

                                                    /// Hàng cuối: Hoa hồng
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        const Text(
                                                          "Hoa hồng:",
                                                          style: TextStyle(fontSize: 14, color: Colors.grey),
                                                        ),
                                                        Text(
                                                          NumberFormat.currency(
                                                            locale: 'vi_VN',
                                                            symbol: 'VND',
                                                            decimalDigits: 0,
                                                          ).format(commission),
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            color: pinkColor,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );


                                        }).toList(),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }


  Widget _buildSalarySection() {
    return FutureBuilder<Map<String, dynamic>>(
      future: SalaryService.getEstimatedSalary(AuthService.getCurrentUser()?['id']),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final salaryData = snapshot.data!;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Lương ước tính ${salaryData['month']}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: mainColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Tạm tính',
                          style: TextStyle(
                            fontSize: 12,
                            color: mainColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          mainColor.withOpacity(0.8),
                          mainColor.withOpacity(0.6),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tổng lương',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          salaryData['formattedTotal'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSalaryDetailRow(
                    'Lương cơ bản',
                    '${NumberFormat.currency(locale: 'vi_VN', symbol: 'VND', decimalDigits: 0).format(salaryData['baseSalary'])}',
                    mainColor,
                  ),
                  _buildSalaryDetailRow(
                    'Số ca làm việc',
                    '${salaryData['workedDays']}/${salaryData['totalWorkdays']} ca',
                    mainColor,
                  ),
                  _buildSalaryDetailRow(
                    'Tổng giờ làm',
                    '${salaryData['totalHours']} giờ',
                    mainColor,
                  ),
                  _buildSalaryDetailRow(
                    'Lương hoa hồng',
                    '${NumberFormat.currency(locale: 'vi_VN', symbol: 'VND', decimalDigits: 0).format(salaryData['totalTip'])}',
                    Colors.orange,
                    isLast: true,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSalaryDetailRow(String label, String value, Color iconColor, {bool isLast = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: iconColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(color: Colors.grey.withOpacity(0.2)),
      ],
    );
  }

}

class _WorkScheduleContent extends StatefulWidget {
  final List<Map<String, dynamic>> schedules;

  const _WorkScheduleContent({required this.schedules});

  @override
  State<_WorkScheduleContent> createState() => _WorkScheduleContentState();
}

class _WorkScheduleContentState extends State<_WorkScheduleContent> {
  int selectedMonth = 0; // 0 = tất cả
  int selectedYear = 0;  // 0 = tất cả
  final Color mainColor = const Color(0xFFFDB5B9);

  @override
  void initState() {
    super.initState();

    final years = widget.schedules
        .map((e) {
      final date = e['date'];
      if (date is String) return DateTime.parse(date).year;
      if (date is DateTime) return date.year;
      return 0;
    })
        .where((y) => y != 0)
        .toSet()
        .toList();

    years.sort();

    selectedYear = years.isNotEmpty ? DateTime.now().year : 0;  // Chỉ chọn năm hiện tại nếu có data, còn không chọn 0
    selectedMonth = DateTime.now().month;
  }

  @override
  Widget build(BuildContext context) {
    final filteredSchedules = widget.schedules.where((schedule) {
      // Convert the string date to DateTime
      final date = schedule['date'] is String
          ? DateTime.parse(schedule['date'])
          : schedule['date'] as DateTime;

      final matchMonth = selectedMonth == 0 || date.month == selectedMonth;
      final matchYear = selectedYear == 0 || date.year == selectedYear;
      return matchMonth && matchYear;
    }).toList();

    final Map<String, List<Map<String, dynamic>>> schedulesByDate = {};
    for (var schedule in filteredSchedules) {
      final date = schedule['formattedDate'] as String;

      schedulesByDate.putIfAbsent(date, () => []).add(schedule);
    }

    return Column(
      children: [
        // 🔽 Bộ lọc tháng/năm
        Padding(
          padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Chọn tháng
                  Row(
                    children: [
                      const Text('Tháng:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: selectedMonth,
                        underline: const SizedBox(),
                        items: [
                          const DropdownMenuItem(value: 0, child: Text('Tất cả')),
                          ...List.generate(12, (i) => i + 1)
                              .map((m) => DropdownMenuItem(value: m, child: Text('Tháng $m')))
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => selectedMonth = value);
                          }
                        },
                      ),
                    ],
                  ),
                  // Chọn năm
                  Row(
                    children: [
                      const Text('Năm:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: selectedYear,
                        underline: const SizedBox(),
                        items: [
                          const DropdownMenuItem(value: 0, child: Text('Tất cả')),
                          ..._buildAvailableYears(widget.schedules)
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => selectedYear = value);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // 🔽 Danh sách lịch làm việc
        Expanded(
          child: filteredSchedules.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  (selectedMonth == 0 && selectedYear == 0)
                      ? 'Không có lịch làm việc nào'
                      : 'Không có lịch làm việc trong tháng $selectedMonth/$selectedYear',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          )
              : ListView(
            padding: const EdgeInsets.all(16),
            children: schedulesByDate.entries.map((entry) {
              final date = entry.key;
              final daySchedules = entry.value;
              final weekday = daySchedules.first['weekday'] as String;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: mainColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              weekday.toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: mainColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            date,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...daySchedules.map((schedule) {
                        final shift = schedule['shift'] as String? ?? '';
                        final checkIn = schedule['checkInTime'] as String? ?? '';
                        final checkOut = schedule['checkOutTime'] as String? ?? '';
                        final status = schedule['status'] as String? ?? '';

                        Color statusColor;
                        IconData statusIcon;

                        switch (status) {
                          case 'On Time':
                            statusColor = Colors.green;
                            statusIcon = Icons.check_circle;
                            break;
                          case 'Late':
                            statusColor = Colors.orange;
                            statusIcon = Icons.warning;
                            break;
                          case 'Absent':
                            statusColor = Colors.red;
                            statusIcon = Icons.cancel;
                            break;
                          case 'Working':
                            statusColor = Colors.blue;
                            statusIcon = Icons.work;
                            break;
                          default:
                            statusColor = Colors.grey;
                            statusIcon = Icons.schedule;
                        }

                        return Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(statusIcon, color: statusColor),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ca $shift',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text('$checkIn - $checkOut'),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  List<DropdownMenuItem<int>> _buildAvailableYears(List<Map<String, dynamic>> schedules) {
    final years = schedules
        .map((e) => (e['date'] as DateTime).year)
        .toSet()
        .toList()
      ..sort();
    return years.map((y) => DropdownMenuItem<int>(value: y, child: Text('$y'))).toList();
  }
}
