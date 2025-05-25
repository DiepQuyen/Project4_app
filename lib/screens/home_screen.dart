import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';

import '../services/attendance_service.dart';
import '../services/auth_service.dart';
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
    final List<Widget> _pages = [
      _buildHomeContent(),
      _buildAttendanceHistory(),
      AccountScreen(
        user: widget.user,
        onLogout: _handleLogout,
      ),
      _buildLeaveRequestPage(),
    ];

    return Scaffold(
      body: _pages[_currentIndex],
      backgroundColor: Colors.white,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: pinkColor.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SalomonBottomBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          items: [
            SalomonBottomBarItem(
              icon: const Icon(Icons.home_rounded),
              title: const Text("Trang chủ"),
              selectedColor: pinkColor,
            ),
            SalomonBottomBarItem(
              icon: const Icon(Icons.history_edu_rounded),
              title: const Text("Lịch sử"),
              selectedColor: pinkColor,
            ),
            SalomonBottomBarItem(
              icon: _buildAvatarIcon(),
              title: const Text("Tài khoản"),
              selectedColor: pinkColor,
            ),
            SalomonBottomBarItem(
              icon: const Icon(Icons.beach_access_rounded),
              title: const Text("Nghỉ phép"),
              selectedColor: pinkColor,
            ),
          ],
        ),
      ),
      floatingActionButton: _currentIndex == 0 ? _buildAttendanceButton() : null,
    );
  }

  Widget _buildAttendanceButton() {
    final now = DateTime.now();
    final bool isCheckedIn = _checkedIn;
    final bool isWorkTime = now.hour < 17 || (now.hour == 17 && now.minute < 30);
    final bool isOnLeave = LeaveService.isOnLeaveForDate(now);

    if (isOnLeave) {
      // User is on approved leave
      return FloatingActionButton.extended(
        onPressed: null, // Disabled
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
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.login),
        label: const Text('Check in', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      );
    } else if (_earlyCheckoutStatus == 'pending') {
      // Waiting for early checkout approval
      return FloatingActionButton.extended(
        onPressed: () => _showEarlyCheckoutStatusDialog(),
        backgroundColor: Colors.amber,
        icon: const Icon(Icons.hourglass_top),
        label: const Text('Đang chờ duyệt về sớm', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      );
    } else if (isWorkTime) {
      // During work hours
      return FloatingActionButton.extended(
        onPressed: () => _showEarlyCheckoutDialog(),
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.exit_to_app),
        label: const Text('Yêu cầu về sớm', style: TextStyle(fontWeight: FontWeight.bold)),
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
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('Checkout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  Widget _buildHomeContent() {
    final now = DateTime.now();
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');
    final weekday = _getWeekday(now.weekday);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with greeting
          _buildHeaderSection(now, dateFormat, timeFormat, weekday),

          // Quick Action Buttons
          _buildQuickActionButtons(),

          // Attendance status card
          _buildAttendanceStatusCard(timeFormat),

          // Summary cards
          _buildSummaryCards(),

          // Weekly stats visualization
          _buildWeeklyStats(),

          // Recent attendance
          _buildRecentAttendanceSection(timeFormat, dateFormat),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(DateTime now, DateFormat dateFormat,
      DateFormat timeFormat, String weekday) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            pinkColor,
            pinkColor.withOpacity(0.7),
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
                  child: Icon(Icons.person, color: pinkColor),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$weekday, ${dateFormat.format(now)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
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
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
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
                    color: pinkColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
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

  Widget _buildAttendanceStatusCard(DateFormat timeFormat) {
    final now = DateTime.now();
    final isWorkTime = now.hour < 17 || (now.hour == 17 && now.minute < 30);
    final isOnLeave = LeaveService.isOnLeaveForDate(now);

    String statusText;
    Color statusColor;

    if (isOnLeave) {
      statusText = 'Đã được nghỉ phép';
      statusColor = Colors.purple;
    } else if (!_checkedIn) {
      statusText = 'Chưa điểm danh';
      statusColor = Colors.red;
    } else if (_checkedIn && _checkoutTime == null) {
      statusText = 'Đã điểm danh lúc ${timeFormat.format(_checkinTime!)}';
      statusColor = Colors.green;
    } else {
      statusText = 'Đã hoàn thành ngày làm việc';
      statusColor = Colors.blue;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 2,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOnLeave ? Icons.event_busy :
                  (_checkedIn ? Icons.check_circle : Icons.access_time),
                  color: statusColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trạng thái hôm nay',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
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
      builder: (dialogContext) => AlertDialog(
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
              final result = await AttendanceService.requestEarlyCheckout(reasonController.text);
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
                        Icon(result['success'] ? Icons.check_circle : Icons.error, color: Colors.white),
                        const SizedBox(width: 10),
                        Text(result['message']),
                      ],
                    ),
                    backgroundColor: result['success'] ? Colors.green : Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                          Icon(result['success'] ? Icons.check_circle : Icons.error, color: Colors.white),
                          const SizedBox(width: 10),
                          Text(result['message']),
                        ],
                      ),
                      backgroundColor: result['success'] ? Colors.green : Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                Text('Thời gian gửi: ${DateFormat('HH:mm dd/MM/yyyy').format(_earlyCheckoutRequestTime!)}'),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Trạng thái: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  if (_earlyCheckoutStatus == 'pending')
                    const Text('Đang chờ duyệt', style: TextStyle(color: Colors.amber)),
                  if (_earlyCheckoutStatus == 'approved')
                    const Text('Đã duyệt', style: TextStyle(color: Colors.green)),
                  if (_earlyCheckoutStatus == 'rejected')
                    const Text('Bị từ chối', style: TextStyle(color: Colors.red)),
                ],
              ),
            ],
          ),
          actions: actions,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        );
      },
    );
  }

  Widget _buildAttendanceHistory() {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');

    // Filter variables
    final ValueNotifier<String> statusFilter = ValueNotifier<String>('all');
    final ValueNotifier<DateTimeRange?> dateRangeFilter = ValueNotifier<DateTimeRange?>(null);

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
                'Lịch sử điểm danh',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Xem lại lịch sử điểm danh của bạn',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),

        // Filter section
        ValueListenableBuilder<String>(
          valueListenable: statusFilter,
          builder: (context, statusValue, child) {
            return ValueListenableBuilder<DateTimeRange?>(
              valueListenable: dateRangeFilter,
              builder: (context, dateRange, _) {
                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Date range picker
                      InkWell(
                        onTap: () async {
                          final result = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
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
                          if (result != null) {
                            dateRangeFilter.value = result;
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, color: pinkColor, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  dateRange != null
                                      ? '${dateFormat.format(dateRange.start)} - ${dateFormat.format(dateRange.end)}'
                                      : 'Chọn khoảng thời gian',
                                  style: TextStyle(
                                    color: dateRange != null ? Colors.black87 : Colors.grey,
                                    fontWeight: dateRange != null ? FontWeight.w500 : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (dateRange != null)
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () {
                                    dateRangeFilter.value = null;
                                  },
                                  color: Colors.grey,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                            ],
                          ),
                        ),
                      ),

                      const Divider(height: 1),

                      // Status filter chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        child: Row(
                          children: [
                            _buildFilterChip('all', 'Tất cả', statusValue, statusFilter),
                            const SizedBox(width: 8),
                            _buildFilterChip('on_time', 'Đúng giờ', statusValue, statusFilter),
                            const SizedBox(width: 8),
                            _buildFilterChip('late', 'Đi muộn', statusValue, statusFilter),
                            const SizedBox(width: 8),
                            _buildFilterChip('early_checkout', 'Về sớm', statusValue, statusFilter),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),

        // Attendance records list
        Expanded(
          child: ValueListenableBuilder<String>(
            valueListenable: statusFilter,
            builder: (context, statusValue, _) {
              return ValueListenableBuilder<DateTimeRange?>(
                valueListenable: dateRangeFilter,
                builder: (context, dateRange, _) {
                  // Apply filters
                  final filteredActivities = _recentActivities.where((activity) {
                    bool passStatusFilter = true;
                    bool passDateFilter = true;

                    // Apply status filter
                    if (statusValue != 'all') {
                      if (statusValue == 'on_time') {
                        passStatusFilter = activity['isOnTime'] == true;
                      } else if (statusValue == 'late') {
                        passStatusFilter = activity['isOnTime'] == false;
                      } else if (statusValue == 'early_checkout') {
                        passStatusFilter = activity['earlyCheckoutStatus'] != null;
                      }
                    }

                    // Apply date range filter
                    if (dateRange != null) {
                      final activityDate = activity['date'] as DateTime;
                      final startDate = DateTime(dateRange.start.year, dateRange.start.month, dateRange.start.day);
                      final endDate = DateTime(dateRange.end.year, dateRange.end.month, dateRange.end.day, 23, 59, 59);
                      passDateFilter = activityDate.isAfter(startDate) && activityDate.isBefore(endDate);
                    }

                    return passStatusFilter && passDateFilter;
                  }).toList();

                  if (filteredActivities.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          const Text(
                            'Không tìm thấy dữ liệu',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredActivities.length,
                    itemBuilder: (context, index) {
                      final record = filteredActivities[index];
                      final date = record['date'] as DateTime;
                      final checkIn = record['checkin'] as DateTime?;
                      final checkOut = record['checkout'] as DateTime?;
                      final isOnTime = record['isOnTime'] as bool? ?? true;
                      final earlyCheckoutStatus = record['earlyCheckoutStatus'] as String?;
                      final earlyCheckoutReason = record['earlyCheckoutReason'] as String?;

                      return Hero(
                        tag: 'attendance-${date.toIso8601String()}',
                        child: TweenAnimationBuilder<double>(
                          duration: Duration(milliseconds: 400 + index * 100),
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, 50 * (1 - value)),
                              child: Opacity(
                                opacity: value,
                                child: child,
                              ),
                            );
                          },
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 2,
                            shadowColor: Colors.black.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                // Date header
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: pinkColor.withOpacity(0.1),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(16),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: pinkColor.withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.event_note, color: pinkColor, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            dateFormat.format(date),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _getWeekday(date.weekday),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isOnTime ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          isOnTime ? 'Đúng giờ' : 'Đi muộn',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isOnTime ? Colors.green : Colors.orange,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Time details with timeline
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Timeline column
                                        Column(
                                          children: [
                                            Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                color: Colors.green.withOpacity(0.2),
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.green, width: 2),
                                              ),
                                              child: const Icon(Icons.login, color: Colors.green, size: 14),
                                            ),
                                            Container(
                                              width: 2,
                                              height: 40,
                                              color: Colors.grey.withOpacity(0.3),
                                            ),
                                            Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withOpacity(0.2),
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.blue, width: 2),
                                              ),
                                              child: const Icon(Icons.logout, color: Colors.blue, size: 14),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(width: 16),

                                        // Time details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      const Text(
                                                        'Check-in',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Row(
                                                        children: [
                                                          Text(
                                                            checkIn != null ? timeFormat.format(checkIn) : '--:--',
                                                            style: const TextStyle(
                                                              fontSize: 18,
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.green,
                                                            ),
                                                          ),
                                                          if (!isOnTime)
                                                            Container(
                                                              margin: const EdgeInsets.only(left: 6),
                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: Colors.orange.withOpacity(0.1),
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                              child: const Text(
                                                                'Muộn',
                                                                style: TextStyle(fontSize: 10, color: Colors.orange),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),

                                              const SizedBox(height: 30),

                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      const Text(
                                                        'Check-out',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        checkOut != null ? timeFormat.format(checkOut) : '--:--',
                                                        style: const TextStyle(
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.blue,
                                                        ),
                                                      ),
                                                    ],
                                                  ),

                                                  if (earlyCheckoutStatus != null && earlyCheckoutStatus != 'none')
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                      decoration: BoxDecoration(
                                                        color: _getStatusColor(earlyCheckoutStatus).withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(12),
                                                        border: Border.all(
                                                          color: _getStatusColor(earlyCheckoutStatus).withOpacity(0.3),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            _getStatusIcon(earlyCheckoutStatus),
                                                            color: _getStatusColor(earlyCheckoutStatus),
                                                            size: 16,
                                                          ),
                                                          const SizedBox(width: 6),
                                                          Text(
                                                            _getStatusText(earlyCheckoutStatus),
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w500,
                                                              color: _getStatusColor(earlyCheckoutStatus),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
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

                                // Early checkout reason
                                if (earlyCheckoutReason != null && earlyCheckoutReason.isNotEmpty)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.withOpacity(0.1)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Lý do xin về sớm:',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            earlyCheckoutReason,
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String value, String label, String selectedValue, ValueNotifier<String> notifier) {
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
                    Icon(Icons.event_note, size: 64, color: Colors.grey.shade300),
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Fix overflow by adding Expanded
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        type == 'sick' ? Icons.medical_services : Icons.beach_access,
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                bottom: MediaQuery.of(modalContext).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.85,
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
                                    onTap: () => setState(() => leaveType = 'regular'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
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
                                    onTap: () => setState(() => leaveType = 'sick'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
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
                                        lastDate: DateTime.now().add(const Duration(days: 90)),
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
                                          if (endDate != null && endDate!.isBefore(date)) {
                                            endDate = date;
                                          }
                                        });
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 14),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
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
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Vui lòng chọn ngày bắt đầu trước'),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                        return;
                                      }

                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: endDate ?? startDate!,
                                        firstDate: startDate!,
                                        lastDate: startDate!.add(const Duration(days: 90)),
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
                                        border: Border.all(color: Colors.grey.shade300),
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
                                  borderSide: BorderSide(color: pinkColor, width: 2),
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
                                onPressed: isSubmitting || startDate == null || endDate == null
                                    ? null
                                    : () async {
                                  setState(() {
                                    isSubmitting = true;
                                  });

                                  final result = await LeaveService.submitLeaveRequest(
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
                                        backgroundColor: result['success'] ? Colors.green : Colors.red,
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
                                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
      builder: (context) => AlertDialog(
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

              final result = await LeaveService.cancelLeaveRequest(requestId);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['message']),
                    backgroundColor: result['success'] ? Colors.green : Colors.red,
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.amber;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle;
      case 'pending':
        return Icons.hourglass_top;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'approved':
        return 'Được duyệt về sớm';
      case 'pending':
        return 'Đang chờ phê duyệt';
      case 'rejected':
        return 'Bị từ chối về sớm';
      default:
        return 'Không xác định';
    }
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