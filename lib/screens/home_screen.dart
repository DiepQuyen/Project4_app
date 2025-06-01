import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';

import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../services/salary_service.dart';
import '../services/schedule_service.dart';
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
  bool _checkedIn = false;
  DateTime? _checkinTime;
  DateTime? _checkoutTime;
  late AnimationController _animController;
  final List<Map<String, dynamic>> _recentActivities = [];
  bool _isProcessingAttendance = false;
  bool _checkoutCompleted = false;
  String _earlyCheckoutStatus = 'none'; // 'none', 'pending', 'approved', 'rejected'
  String _earlyCheckoutReason = '';
  DateTime? _earlyCheckoutRequestTime;

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
          : _currentIndex == 3
          ? _buildLeaveRequestPage()
          : AccountScreen(
        user: widget.user,
        onLogout: _handleLogout,
      ),
      bottomNavigationBar: SalomonBottomBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
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
            icon: const Icon(Icons.beach_access_outlined),
            activeIcon: const Icon(Icons.beach_access),
            title: const Text('Nghỉ phép'),
            selectedColor: pinkColor,
          ),
          SalomonBottomBarItem(
            icon: _currentIndex == 4 ?
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

          // Attendance Status Card
          _buildAttendanceStatusCard(timeFormat),

          // Estimated Salary Card
          _buildSalarySection(),

          // Summary Cards
          const SizedBox(height: 16),
          _buildSummaryCards(),

          // Weekly Stats
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
    return FutureBuilder<Map<String, dynamic>>(
      future: ScheduleService.getTodayStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            margin: EdgeInsets.all(16),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final data = snapshot.data ?? {'hasShift': false, 'message': 'Đang tải...', 'status': 'Unknown'};
        final hasShift = data['hasShift'] as bool;

        if (!hasShift) {
          return Card(
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.event_busy, color: Colors.grey[600], size: 26),
                      const SizedBox(width: 12),
                      Text(
                        'Trạng thái hôm nay',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    data['message'] ?? 'Không có ca làm việc hôm nay',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        final schedules = (data['schedules'] as List<dynamic>);

        return Card(
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.event_available, color: mainColor, size: 26),
                    const SizedBox(width: 12),
                    Text(
                      'Trạng thái hôm nay',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ...schedules.map((schedule) {
                  final shift = schedule['shift'] as String;
                  final status = schedule['status'] as String;
                  final checkIn = schedule['checkInTime'] as String;
                  final checkOut = schedule['checkOutTime'] as String;

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

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
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
                                'Ca $shift: $checkIn - $checkOut',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                status,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
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
      },
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

        if (schedules.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Không có lịch làm việc',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        // Group schedules by date
        final Map<String, List<Map<String, dynamic>>> schedulesByDate = {};
        for (var schedule in schedules) {
          final date = schedule['formattedDate'] as String;
          if (!schedulesByDate.containsKey(date)) {
            schedulesByDate[date] = [];
          }
          schedulesByDate[date]!.add(schedule);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Legend
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chú thích',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildLegendItem(color: Colors.green, text: 'Đúng giờ'),
                      const SizedBox(width: 16),
                      _buildLegendItem(color: Colors.orange, text: 'Đi muộn'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildLegendItem(color: Colors.red, text: 'Vắng mặt'),
                      const SizedBox(width: 16),
                      _buildLegendItem(color: Colors.blue, text: 'Đang làm việc'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Schedule cards
            ...schedulesByDate.entries.map((entry) {
              final date = entry.key;
              final daySchedules = entry.value;
              final firstSchedule = daySchedules.first;
              final weekday = firstSchedule['weekday'] as String;

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
                              weekday.substring(0, 3).toUpperCase(),
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
                        final shift = schedule['shift'] as String;
                        final checkIn = schedule['checkInTime'] as String;
                        final checkOut = schedule['checkOutTime'] as String;
                        final status = schedule['status'] as String;

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
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
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
          ],
        );
      },
    );
  }

  Widget _buildAttendanceButton() {
    final now = DateTime.now();
    final bool isCheckedIn = _checkedIn;
    final bool isWorkTime = now.hour < 17 ||
        (now.hour == 17 && now.minute < 30);
    final bool isOnLeave = LeaveService.isOnLeaveForDate(now);

    if (isOnLeave) {
      // User is on approved leave
      return FloatingActionButton.extended(
        onPressed: null,
        // Disabled
        backgroundColor: Colors.grey.shade300,
        icon: const Icon(Icons.event_busy, color: Colors.grey),
        label: const Text(
          'Đã được nghỉ phép',
          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      );
    } else if (!_checkedIn) {
      // Not checked in yet
      return FloatingActionButton.extended(
        onPressed: _isProcessingAttendance ? null : _handleAttendanceAction,
        backgroundColor: Colors.green,
        icon: _isProcessingAttendance
            ? const SizedBox(width: 20,
            height: 20,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.login),
        label: const Text(
            'Check in', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      );
    } else if (_earlyCheckoutStatus == 'pending') {
      // Waiting for early checkout approval
      return FloatingActionButton.extended(
        onPressed: () => _showEarlyCheckoutStatusDialog(),
        backgroundColor: Colors.amber,
        icon: const Icon(Icons.hourglass_top),
        label: const Text('Đang chờ duyệt về sớm',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      );
    } else if (isWorkTime) {
      // During work hours
      return FloatingActionButton.extended(
        onPressed: () => _showEarlyCheckoutDialog(),
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.exit_to_app),
        label: const Text(
            'Yêu cầu về sớm', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      );
    } else {
      // Checked in, after work time, can check out
      return FloatingActionButton.extended(
        onPressed: _isProcessingAttendance ? null : _handleAttendanceAction,
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.logout, size: 22),
        label: _isProcessingAttendance
            ? const SizedBox(width: 20,
            height: 20,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2))
            : const Text('Checkout',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      );
    }
  }

  Future<void> _handleAttendanceAction() async {
    // Check if on leave first
    final now = DateTime.now();
    if (LeaveService.isOnLeaveForDate(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Bạn đã được nghỉ phép hôm nay'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isProcessingAttendance = true;
    });

    try {
      if (!_checkedIn) {
        // Perform check-in
        final result = await AttendanceService.checkIn();
        if (result['success']) {
          _handleCheckin();
        } else {
          throw Exception(result['message']);
        }
      } else {
        // Perform check-out
        final result = await AttendanceService.checkOut();
        if (result['success']) {
          _handleCheckout();
          _checkoutCompleted = true;
        } else {
          throw Exception(result['message']);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isProcessingAttendance = false;
      });
    }
  }


  void _simulateNextDay() {
    // For demo, we'll just use a delayed function
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          // Reset for new day
          _checkedIn = false;
          _checkinTime = null;
          _checkoutTime = null;
          _checkoutCompleted = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          _buildSuccessSnackbar('Ngày mới đã bắt đầu - có thể điểm danh lại'),
        );
      }
    });
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

    // Load avatar image safely
    _loadAvatarImage();
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

  void _generateSampleData() {
    final now = DateTime.now();

    // Create recent activities
    for (int i = 0; i < 5; i++) {
      final date = now.subtract(Duration(days: i));
      final bool isOnTime = i % 3 != 1; // Make some days late

      _recentActivities.add({
        'date': date,
        'checkin': DateTime(
            date.year, date.month, date.day, 8, isOnTime ? 0 : 25),
        'checkout': DateTime(date.year, date.month, date.day, 17, 30 + i * 5),
        'isOnTime': isOnTime,
      });
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

  void _handleCheckin() {
    setState(() {
      _checkedIn = true;
      _checkinTime = DateTime.now();
    });

    _animController.forward(from: 0.0);

    ScaffoldMessenger.of(context).showSnackBar(
        _buildSuccessSnackbar('Điểm danh thành công'));
  }

  void _handleCheckout() {
    setState(() {
      _checkoutTime = DateTime.now();
    });

    _animController.forward(from: 0.0);

    ScaffoldMessenger.of(context).showSnackBar(
        _buildSuccessSnackbar('Checkout thành công'));
  }

  SnackBar _buildSuccessSnackbar(String message) {
    return SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 10),
          Text(message),
        ],
      ),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildAvatarIcon() {
    if (_imageLoaded) {
      return CircleAvatar(
        backgroundImage: _avatarImage,
        radius: 14,
        backgroundColor: Colors.white,
      );
    } else {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: pinkColor.withOpacity(0.2),
        ),
        child: Center(
          child: Icon(Icons.person, size: 14, color: pinkColor),
        ),
      );
    }
  }

  Widget _buildHeaderSection(DateTime now, DateFormat dateFormat,
      DateFormat timeFormat, Color color) {
    // Get weekday name using DateFormat
    final String weekdayName = DateFormat('EEEE').format(now);

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
                      '${dateFormat.format(now)}',
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

  Widget _buildQuickActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Card(
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickAction(
                icon: Icons.calendar_today,
                label: 'Lịch làm việc',
                onTap: () {},
              ),
              _buildQuickAction(
                icon: Icons.assignment_turned_in,
                label: 'Yêu cầu',
                onTap: () {},
              ),
              _buildQuickAction(
                icon: Icons.notifications,
                label: 'Thông báo',
                onTap: () {},
                showBadge: true,
              ),
              _buildQuickAction(
                icon: Icons.help_outline,
                label: 'Trợ giúp',
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool showBadge = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: pinkColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: pinkColor, size: 22),
              ),
              if (showBadge)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        '1',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                )
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              icon: Icons.calendar_month,
              title: 'Tháng này',
              value: '22/23',
              subtitle: 'ngày làm việc',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              icon: Icons.watch_later_outlined,
              title: 'Đúng giờ',
              value: '95%',
              subtitle: 'tỉ lệ',
              valueColor: Colors.green,
            ),
          ),
        ],
      ),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Thống kê tuần này',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: pinkColor,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn('T2', 0.9),
                  _buildStatColumn('T3', 0.7),
                  _buildStatColumn('T4', 1.0),
                  _buildStatColumn('T5', 0.8),
                  _buildStatColumn('T6', 0.95),
                  _buildStatColumn('T7', 0.5),
                  _buildStatColumn('CN', 0.0),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tổng giờ làm: 38 giờ',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: pinkColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Thời gian làm việc',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, double ratio) {
    final height = ratio > 0 ? 80.0 * ratio : 2.0;

    return Column(
      children: [
        SizedBox(height: 80 - height),
        Container(
          width: 20,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: ratio > 0 ? pinkColor : Colors.grey.shade300,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

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
                  color: pinkColor,
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
                    color: Colors.grey.shade600,
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

  void _showEarlyCheckoutDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) =>
          AlertDialog(
            title: const Text('Xin phê duyệt về sớm'),
            content: TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'Lý do'),
              maxLines: 2,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  setState(() => _isProcessingAttendance = true);
                  final result = await AttendanceService.requestEarlyCheckout(
                      reasonController.text);
                  setState(() {
                    _isProcessingAttendance = false;
                    if (result['success']) {
                      _earlyCheckoutStatus = 'pending';
                      _earlyCheckoutReason = reasonController.text;
                      _earlyCheckoutRequestTime = DateTime.now();
                    }
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(result['success'] ? Icons.check_circle : Icons
                                .error, color: Colors.white),
                            const SizedBox(width: 10),
                            Text(result['message']),
                          ],
                        ),
                        backgroundColor: result['success']
                            ? Colors.green
                            : Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                },
                child: const Text('Gửi'),
              ),
            ],
          ),
    );
  }

  void _showEarlyCheckoutStatusDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        List<Widget> actions = [];
        if (_earlyCheckoutStatus == 'rejected') {
          actions = [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy bỏ'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showEarlyCheckoutDialog();
              },
              child: const Text('Gửi lại yêu cầu'),
            ),
          ];
        } else if (_earlyCheckoutStatus == 'approved') {
          actions = [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy bỏ'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                setState(() => _isProcessingAttendance = true);
                final result = await AttendanceService.checkOut();
                setState(() {
                  _isProcessingAttendance = false;
                  if (result['success']) {
                    _checkoutTime = DateTime.now();
                    _earlyCheckoutStatus = 'none';
                  }
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(result['success'] ? Icons.check_circle : Icons
                              .error, color: Colors.white),
                          const SizedBox(width: 10),
                          Text(result['message']),
                        ],
                      ),
                      backgroundColor: result['success'] ? Colors.green : Colors
                          .red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              },
              child: const Text('Checkout'),
            ),
          ];
        }
        // If pending, no actions

        return AlertDialog(
          title: const Text('Thông tin phê duyệt về sớm'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Lý do: $_earlyCheckoutReason'),
              if (_earlyCheckoutRequestTime != null)
                Text('Thời gian gửi: ${DateFormat('HH:mm dd/MM/yyyy').format(
                    _earlyCheckoutRequestTime!)}'),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Trạng thái: ',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  if (_earlyCheckoutStatus == 'pending')
                    const Text('Đang chờ duyệt',
                        style: TextStyle(color: Colors.amber)),
                  if (_earlyCheckoutStatus == 'approved')
                    const Text(
                        'Đã duyệt', style: TextStyle(color: Colors.green)),
                  if (_earlyCheckoutStatus == 'rejected')
                    const Text(
                        'Bị từ chối', style: TextStyle(color: Colors.red)),
                ],
              ),
            ],
          ),
          actions: actions,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        );
      },
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
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withOpacity(0.7),
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
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');

    // Mock data for attendance history
    final attendanceRecords = List.generate(
      30,
          (index) {
        final date = DateTime.now().subtract(Duration(days: index));
        final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

        // Skip weekends or random days for variety
        if (isWeekend || (index > 5 && index % 7 == 0)) {
          return {
            'date': date,
            'checkin': null,
            'checkout': null,
            'status': 'absence',
            'earlyCheckoutStatus': null,
            'earlyCheckoutReason': null,
          };
        }

        // Regular attendance
        final checkinTime = DateTime(
            date.year, date.month, date.day,
            7 + (index % 2), 45 + (index % 15)
        );

        final checkoutTime = index % 10 == 0
            ? DateTime(date.year, date.month, date.day, 16, 30)
            : DateTime(date.year, date.month, date.day, 17, 30 + (index % 30));

        final isEarlyCheckout = checkoutTime.hour < 17 ||
            (checkoutTime.hour == 17 && checkoutTime.minute < 30);

        return {
          'date': date,
          'checkin': checkinTime,
          'checkout': checkoutTime,
          'status': 'present',
          'earlyCheckoutStatus': isEarlyCheckout ?
          (index % 3 == 0 ? 'approved' : (index % 3 == 1 ? 'pending' : 'rejected')) : null,
          'earlyCheckoutReason': isEarlyCheckout ?
          'Lý do về sớm ${index % 3 == 0 ? "(đã duyệt)" : index % 3 == 1 ? "(đang chờ)" : "(từ chối)"}' : null,
        };
      },
    );

    // Filter variables
    final months = <String>['Tất cả', ...List.generate(
        6, (i) => DateFormat('MM/yyyy').format(DateTime.now().subtract(Duration(days: 30 * i)))
    ).toSet().toList()];

    final statusOptions = ['Tất cả', 'Đi làm', 'Vắng mặt', 'Đi muộn', 'Về sớm'];

    final monthValue = ValueNotifier<String>(months[0]);
    final statusValue = ValueNotifier<String>(statusOptions[0]);

    return Column(
      children: [
        // Filter section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lọc theo:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ValueListenableBuilder<String>(
                      valueListenable: monthValue,
                      builder: (context, value, _) {
                        return DropdownButtonFormField<String>(
                          value: value,
                          decoration: InputDecoration(
                            labelText: 'Tháng',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: months.map((month) {
                            return DropdownMenuItem(
                              value: month,
                              child: Text(month),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            if (newValue != null) {
                              monthValue.value = newValue;
                            }
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ValueListenableBuilder<String>(
                      valueListenable: statusValue,
                      builder: (context, value, _) {
                        return DropdownButtonFormField<String>(
                          value: value,
                          decoration: InputDecoration(
                            labelText: 'Trạng thái',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: statusOptions.map((status) {
                            return DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            if (newValue != null) {
                              statusValue.value = newValue;
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Attendance list
        Expanded(
          child: ValueListenableBuilder<String>(
            valueListenable: statusValue,
            builder: (context, statusValue, child) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (final record in attendanceRecords)
                      if (_filterRecord(record, monthValue.value, statusValue))
                        Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                                        color: _getStatusColor(record['status']?.toString() ?? '').withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        _getStatusIcon(record['status']?.toString() ?? ''),
                                        color: _getStatusColor(record['status']?.toString() ?? ''),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            dateFormat.format(record['date'] as DateTime),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _getStatusText(record['status']?.toString() ?? ''),
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: _getStatusColor(record['status']?.toString() ?? ''),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (record['checkin'] != null || record['checkout'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Giờ vào',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                record['checkin'] != null
                                                    ? timeFormat.format(record['checkin'] as DateTime)
                                                    : '---',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: record['checkin'] != null
                                                      ? Colors.black87
                                                      : Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Giờ ra',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                record['checkout'] != null
                                                    ? timeFormat.format(record['checkout'] as DateTime)
                                                    : '---',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: record['checkout'] != null
                                                      ? Colors.black87
                                                      : Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (record['earlyCheckoutReason'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.info_outline,
                                                size: 16,
                                                color: _getEarlyCheckoutStatusColor(
                                                    record['earlyCheckoutStatus']?.toString() ?? ''),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Yêu cầu về sớm',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: _getEarlyCheckoutStatusColor(
                                                      record['earlyCheckoutStatus']?.toString() ?? ''),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            record['earlyCheckoutReason']?.toString() ?? '',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

// Helper method to filter records by month and status
  bool _filterRecord(Map<String, dynamic> record, String month, String status) {
    final recordDate = record['date'] as DateTime;

    // Filter by month
    if (month != 'Tất cả') {
      final recordMonth = DateFormat('MM/yyyy').format(recordDate);
      if (recordMonth != month) return false;
    }

    // Filter by status
    if (status != 'Tất cả') {
      final recordStatus = record['status'] as String;
      if (status == 'Đi làm' && recordStatus != 'present') return false;
      if (status == 'Vắng mặt' && recordStatus != 'absence') return false;
      if (status == 'Đi muộn') {
        final checkin = record['checkin'] as DateTime?;
        if (checkin == null || checkin.hour < 9) return false;
      }
      if (status == 'Về sớm' && record['earlyCheckoutStatus'] == null) return false;
    }

    return true;
  }

// Helper method to get status icon
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'present':
        return Icons.check_circle;
      case 'absence':
        return Icons.cancel;
      default:
        return Icons.access_time;
    }
  }

// Helper method to get status color
  Color _getStatusColor(String status) {
    switch (status) {
      case 'present':
        return Colors.green;
      case 'absence':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

// Helper method to get status text
  String _getStatusText(String status) {
    switch (status) {
      case 'present':
        return 'Có mặt';
      case 'absence':
        return 'Vắng mặt';
      default:
        return 'Chưa xác định';
    }
  }

// Helper method to get early checkout status color
  Color _getEarlyCheckoutStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  Widget _buildOrdersHistoryTab() {
    return FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
      future: OrderService.getMonthlyHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: pinkColor),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const Center(
            child: Text('Không thể tải lịch sử đơn hàng'),
          );
        }

        final monthlyData = snapshot.data!;
        final months = monthlyData.keys.toList()..sort((a, b) => b.compareTo(a));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: months.length,
          itemBuilder: (context, monthIndex) {
            final month = months[monthIndex];
            final monthData = monthlyData[month]!;

            // First item is the month summary
            final summary = monthData.first;
            final isExpanded = ValueNotifier<bool>(monthIndex == 0);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Month header with earnings
                InkWell(
                  onTap: () => isExpanded.value = !isExpanded.value,
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: pinkColor.withOpacity(0.1),
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tháng $month',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tổng thu nhập: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(summary['totalEarnings'])}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Lương cơ bản: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(summary['baseSalary'])}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Hoa hồng: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(summary['totalCommission'])}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ValueListenableBuilder<bool>(
                            valueListenable: isExpanded,
                            builder: (context, expanded, _) {
                              return Icon(
                                expanded ? Icons.expand_less : Icons.expand_more,
                                color: Colors.grey.shade700,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Order list for this month
                ValueListenableBuilder<bool>(
                  valueListenable: isExpanded,
                  builder: (context, expanded, _) {
                    if (!expanded) return const SizedBox.shrink();

                    // Skip the first item (summary) and show orders
                    final orders = monthData.skip(1).toList();

                    if (orders.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'Không có đơn hàng trong tháng này',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      );
                    }

                    // Group orders by date
                    final ordersByDate = <String, List<Map<String, dynamic>>>{};
                    for (var order in orders) {
                      final dateStr = order['dateDisplay'] as String;
                      ordersByDate[dateStr] ??= [];
                      ordersByDate[dateStr]!.add(order);
                    }

                    final dates = ordersByDate.keys.toList()
                      ..sort((a, b) => b.compareTo(a));

                    return ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: dates.length,
                      itemBuilder: (context, dateIndex) {
                        final date = dates[dateIndex];
                        final dateOrders = ordersByDate[date]!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                              child: Text(
                                date,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ...dateOrders.map((order) => _buildOrderItem(order)),
                          ],
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 16),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTodaySchedule(Map<int, Map<String, bool>> schedule) {
    final now = DateTime.now();
    final day = now.weekday;
    final dayName = _getWeekday(day);
    final hasMorningShift = schedule[day]!['morning'] as bool;
    final hasAfternoonShift = schedule[day]!['afternoon'] as bool;

    final currentHour = now.hour;
    final isMorningShiftActive = hasMorningShift && currentHour >= 8 && currentHour < 12;
    final isAfternoonShiftActive = hasAfternoonShift && currentHour >= 13 && currentHour < 18;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: pinkColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.today,
                    color: pinkColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hôm nay',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$dayName, ${DateFormat('dd/MM/yyyy').format(now)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildShiftCard(
                    title: 'Ca sáng',
                    time: '08:00 - 12:00',
                    isScheduled: hasMorningShift,
                    isActive: isMorningShiftActive,
                    color: pinkColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildShiftCard(
                    title: 'Ca chiều',
                    time: '13:30 - 17:30',
                    isScheduled: hasAfternoonShift,
                    isActive: isAfternoonShiftActive,
                    color: const Color(0xFF5C6BC0),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftCard({
    required String title,
    required String time,
    required bool isScheduled,
    required bool isActive,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isScheduled ? color.withOpacity(0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border.all(color: color, width: 2)
            : Border.all(color: Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isScheduled ? Icons.check_circle : Icons.cancel,
                color: isScheduled ? color : Colors.grey,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isScheduled ? color : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isScheduled ? time : 'Nghỉ',
            style: TextStyle(
              fontSize: 14,
              color: isScheduled ? Colors.black87 : Colors.grey,
            ),
          ),
          if (isActive) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Đang diễn ra',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDayScheduleRow({
    required int day,
    required String dayName,
    required bool morning,
    required bool afternoon,
  }) {
    final isToday = DateTime.now().weekday == day;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: isToday ? pinkColor.withOpacity(0.1) : Colors.transparent,
        border: Border.all(
          color: isToday ? pinkColor.withOpacity(0.3) : Colors.grey.shade200,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Day name
          SizedBox(
            width: 80,
            child: Text(
              dayName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                color: isToday ? pinkColor : Colors.black87,
              ),
            ),
          ),

          // Morning shift
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: morning ? pinkColor.withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    morning ? Icons.check : Icons.close,
                    color: morning ? pinkColor : Colors.grey,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Sáng',
                    style: TextStyle(
                      fontSize: 14,
                      color: morning ? pinkColor : Colors.grey,
                      fontWeight: morning ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Afternoon shift
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: afternoon ? const Color(0xFF5C6BC0).withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    afternoon ? Icons.check : Icons.close,
                    color: afternoon ? const Color(0xFF5C6BC0) : Colors.grey,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Chiều',
                    style: TextStyle(
                      fontSize: 14,
                      color: afternoon ? const Color(0xFF5C6BC0) : Colors.grey,
                      fontWeight: afternoon ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String text,
  }) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
          ),
        ),
      ],
    );
  }


  Widget _buildOrderItem(Map<String, dynamic> order) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    order['service'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: order['status'] == 'Hoàn thành'
                        ? Colors.green.withOpacity(0.1)
                        : order['status'] == 'Đang thực hiện'
                        ? Colors.blue.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order['status'],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: order['status'] == 'Hoàn thành'
                          ? Colors.green
                          : order['status'] == 'Đang thực hiện'
                          ? Colors.blue
                          : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  order['timeDisplay'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Rating stars
                Row(
                  children: [
                    ...List.generate(5, (index) {
                      return Icon(
                        index < (order['rating'] as int)
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber,
                        size: 18,
                      );
                    }),
                  ],
                ),

                // Commission
                Text(
                  NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0)
                      .format(order['commission']),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildFilterChip(String value, String label, String selectedValue,
      ValueNotifier<String> notifier) {
    final isSelected = selectedValue == value;

    return InkWell(
      onTap: () {
        notifier.value = value;
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? pinkColor : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildLeaveRequestPage() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: LeaveService.getLeaveRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: pinkColor));
        }

        final leaveRequests = snapshot.data ?? [];

        return Column(
          children: [
            // Header with gradient
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [pinkColor, pinkColor.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: pinkColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yêu cầu nghỉ phép',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Quản lý và theo dõi các yêu cầu nghỉ phép của bạn',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),

            // Leave statistics
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildLeaveStatCard(
                      title: 'Còn lại',
                      value: '12',
                      icon: Icons.calendar_today_outlined,
                      iconColor: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildLeaveStatCard(
                      title: 'Đã dùng',
                      value: '3',
                      icon: Icons.event_busy,
                      iconColor: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),

            // Create new request button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: () => _showLeaveRequestForm(context),
                icon: const Icon(Icons.add),
                label: const Text('Tạo yêu cầu mới'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: pinkColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            // Leave requests list
            Expanded(
              child: leaveRequests.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_note, size: 64,
                        color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'Chưa có yêu cầu nghỉ phép nào',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tạo yêu cầu mới ngay',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: leaveRequests.length,
                itemBuilder: (context, index) {
                  return _buildLeaveRequestItem(leaveRequests[index]);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLeaveStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'ngày',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveRequestItem(Map<String, dynamic> request) {
    final DateFormat dateFormat = DateFormat('dd/MM/yyyy');
    final startDate = request['startDate'] as DateTime;
    final endDate = request['endDate'] as DateTime;
    final daysCount = request['daysCount'];
    final status = request['status'] as String;
    final type = request['type'] as String;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Đã duyệt';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Bị từ chối';
        break;
      default:
        statusColor = Colors.amber;
        statusIcon = Icons.hourglass_top;
        statusText = 'Đang chờ duyệt';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // Header with leave type and status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: pinkColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Fix overflow by adding Expanded
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        type == 'sick' ? Icons.medical_services : Icons
                            .beach_access,
                        size: 20,
                        color: pinkColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        type == 'sick' ? 'Nghỉ ốm' : 'Nghỉ phép thường',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(fontSize: 12, color: statusColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Date information
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ngày bắt đầu',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dateFormat.format(startDate),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ngày kết thúc',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dateFormat.format(endDate),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: pinkColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$daysCount ngày',
                        style: TextStyle(
                          color: pinkColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (status == 'pending')
                      TextButton.icon(
                        onPressed: () => _confirmCancelRequest(request['id']),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Hủy yêu cầu'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
                if (request['reason']?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Lý do:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    request['reason'],
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLeaveRequestForm(BuildContext context) {
    final DateFormat dateFormat = DateFormat('dd/MM/yyyy');
    final formKey = GlobalKey<FormState>();

    DateTime? startDate;
    DateTime? endDate;
    String reason = '';
    String leaveType = 'regular'; // 'regular' or 'sick'
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        // Create the focus node inside the builder so it lives with the modal
        final reasonFocusNode = FocusNode();
        final scrollController = ScrollController();

        // Add listener to focus node
        reasonFocusNode.addListener(() {
          if (reasonFocusNode.hasFocus) {
            // Delayed scroll to ensure keyboard is fully shown
            Future.delayed(const Duration(milliseconds: 300), () {
              if (scrollController.hasClients) {
                scrollController.animateTo(
                  scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });
          }
        });

        return StatefulBuilder(
          builder: (stateContext, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery
                    .of(modalContext)
                    .viewInsets
                    .bottom,
              ),
              child: Container(
                height: MediaQuery
                    .of(context)
                    .size
                    .height * 0.85,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(25),
                    topRight: Radius.circular(25),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Form header
                    Container(
                      // Header styling
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: pinkColor.withOpacity(0.1),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(25),
                          topRight: Radius.circular(25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.event_available, color: pinkColor),
                          const SizedBox(width: 10),
                          const Text(
                            'Đơn xin nghỉ phép',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(modalContext),
                          ),
                        ],
                      ),
                    ),

                    // Form content - scrollable
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: ListView(
                          controller: scrollController,
                          children: [
                            // Leave type selection
                            Text(
                              'Loại nghỉ phép',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () =>
                                        setState(() => leaveType = 'regular'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      decoration: BoxDecoration(
                                        color: leaveType == 'regular'
                                            ? pinkColor
                                            : Colors.grey.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Nghỉ thường',
                                          style: TextStyle(
                                            color: leaveType == 'regular'
                                                ? Colors.white
                                                : Colors.black87,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: InkWell(
                                    onTap: () =>
                                        setState(() => leaveType = 'sick'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      decoration: BoxDecoration(
                                        color: leaveType == 'sick'
                                            ? pinkColor
                                            : Colors.grey.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Nghỉ bệnh',
                                          style: TextStyle(
                                            color: leaveType == 'sick'
                                                ? Colors.white
                                                : Colors.black87,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Date pickers
                            Text(
                              'Thời gian nghỉ',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                // Start date picker
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: DateTime.now(),
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime.now().add(
                                            const Duration(days: 90)),
                                        builder: (context, child) {
                                          return Theme(
                                            data: Theme.of(context).copyWith(
                                              colorScheme: ColorScheme.light(
                                                primary: pinkColor,
                                              ),
                                            ),
                                            child: child!,
                                          );
                                        },
                                      );
                                      if (date != null) {
                                        setState(() {
                                          startDate = date;
                                          // Reset end date if it's before start date
                                          if (endDate != null &&
                                              endDate!.isBefore(date)) {
                                            endDate = date;
                                          }
                                        });
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 14),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.calendar_today,
                                              size: 18, color: pinkColor),
                                          const SizedBox(width: 8),
                                          Text(
                                            startDate != null
                                                ? dateFormat.format(startDate!)
                                                : 'Từ ngày',
                                            style: TextStyle(
                                              color: startDate != null
                                                  ? Colors.black87
                                                  : Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // End date picker
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      if (startDate == null) {
                                        ScaffoldMessenger
                                            .of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Vui lòng chọn ngày bắt đầu trước'),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                        return;
                                      }

                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: endDate ?? startDate!,
                                        firstDate: startDate!,
                                        lastDate: startDate!.add(
                                            const Duration(days: 90)),
                                        builder: (context, child) {
                                          return Theme(
                                            data: Theme.of(context).copyWith(
                                              colorScheme: ColorScheme.light(
                                                primary: pinkColor,
                                              ),
                                            ),
                                            child: child!,
                                          );
                                        },
                                      );
                                      if (date != null) {
                                        setState(() {
                                          endDate = date;
                                        });
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 14),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.calendar_today,
                                              size: 18, color: pinkColor),
                                          const SizedBox(width: 8),
                                          Text(
                                            endDate != null
                                                ? dateFormat.format(endDate!)
                                                : 'Đến ngày',
                                            style: TextStyle(
                                              color: endDate != null
                                                  ? Colors.black87
                                                  : Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Reason text field
                            Text(
                              'Lý do xin nghỉ',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              focusNode: reasonFocusNode,
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: 'Nhập lý do xin nghỉ của bạn',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: pinkColor, width: 2),
                                ),
                              ),
                              onChanged: (value) {
                                reason = value;
                              },
                            ),
                            const SizedBox(height: 24),

                            // Submit button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: isSubmitting || startDate == null ||
                                    endDate == null
                                    ? null
                                    : () async {
                                  setState(() {
                                    isSubmitting = true;
                                  });

                                  final result = await LeaveService
                                      .submitLeaveRequest(
                                    startDate: startDate!,
                                    endDate: endDate!,
                                    reason: reason,
                                    type: leaveType,
                                  );

                                  if (modalContext.mounted) {
                                    Navigator.pop(modalContext);
                                  }

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(result['message']),
                                        backgroundColor: result['success']
                                            ? Colors.green
                                            : Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );

                                    // Reset the state
                                    this.setState(() {});

                                    // Fake a delay to simulate manager responding
                                    LeaveService.simulateManagerAction();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: pinkColor,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 2,
                                ),
                                child: isSubmitting
                                    ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                    : const Text(
                                  'Gửi yêu cầu',
                                  style: TextStyle(fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmCancelRequest(String requestId) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('Xác nhận hủy'),
            content: const Text('Bạn có chắc muốn hủy yêu cầu nghỉ phép này?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Không'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);

                  final result = await LeaveService.cancelLeaveRequest(
                      requestId);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message']),
                        backgroundColor: result['success']
                            ? Colors.green
                            : Colors.red,
                      ),
                    );
                  }

                  // Force refresh the page
                  setState(() {});
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('Hủy yêu cầu'),
              ),
            ],
          ),
    );
  }

  Widget _buildSalarySection() {
    return FutureBuilder<Map<String, dynamic>>(
      future: SalaryService.getEstimatedSalary(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                height: 4,
                child: LinearProgressIndicator(),
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Không thể tải thông tin lương'),
            ),
          );
        }

        final salaryData = snapshot.data!;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1E3C72),
                const Color(0xFF2A5298),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Lương tạm tính (${salaryData['month']})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${salaryData['workedDays']}/${salaryData['totalWorkdays']} ngày',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  salaryData['formattedTotal'],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tổng giờ làm',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${salaryData['totalHours']} giờ',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Giờ làm thêm',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${salaryData['overtimeHours']} giờ',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getWeekday(int weekday) {
    switch (weekday) {
      case 1:
        return 'Thứ Hai';
      case 2:
        return 'Thứ Ba';
      case 3:
        return 'Thứ Tư';
      case 4:
        return 'Thứ Năm';
      case 5:
        return 'Thứ Sáu';
      case 6:
        return 'Thứ Bảy';
      case 7:
        return 'Chủ Nhật';
      default:
        return '';
    }
  }
}