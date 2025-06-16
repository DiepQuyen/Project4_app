import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class OrderService {
  static const String baseUrl = 'http://10.0.2.2:8080';
  static final Random _random = Random();
  static final List<String> _services = [
    'Cắt tóc nam', 'Cắt tóc nữ', 'Uốn tóc', 'Nhuộm tóc',
    'Gội đầu', 'Massage mặt', 'Chăm sóc da', 'Làm móng',
    'Tẩy da chết', 'Xông hơi'
  ];

  static final List<String> _statuses = ['Hoàn thành', 'Đang thực hiện', 'Đã hủy'];

  // static Future<List<Map<String, dynamic>>> getTodayOrders() async {
  //   await Future.delayed(const Duration(milliseconds: 800));
  //
  //   final now = DateTime.now();
  //   final timeFormat = DateFormat('HH:mm');
  //   final orders = <Map<String, dynamic>>[];
  //
  //   // Generate 0-5 random orders for today
  //   final orderCount = _random.nextInt(6);
  //
  //   // List of customer names
  //   final customerNames = [
  //     'Nguyễn Thị Hương', 'Trần Văn Nam', 'Lê Thị Hà', 'Phạm Thanh Thảo',
  //     'Hoàng Minh Tuấn', 'Vũ Thị Lan', 'Đặng Văn Hùng', 'Ngô Thị Mai'
  //   ];
  //
  //   for (int i = 0; i < orderCount; i++) {
  //     final startHour = 8 + _random.nextInt(10); // Between 8 AM and 6 PM
  //     final startMinute = _random.nextInt(60);
  //     final orderTime = DateTime(now.year, now.month, now.day, startHour, startMinute);
  //
  //     // Random duration between 30 minutes and 2 hours
  //     final durationMinutes = 30 + _random.nextInt(90);
  //     final endTime = orderTime.add(Duration(minutes: durationMinutes));
  //
  //     // Random service
  //     final service = _services[_random.nextInt(_services.length)];
  //
  //     // Random customer
  //     final customerName = customerNames[_random.nextInt(customerNames.length)];
  //
  //     // Random rating (1-5)
  //     final rating = 1 + _random.nextInt(5);
  //
  //     // Random commission (50,000 - 200,000 VND)
  //     final commission = 50000 + _random.nextInt(150000);
  //
  //     // Random status (completed if order time has passed)
  //     String status;
  //     if (now.isAfter(endTime)) {
  //       status = 'Hoàn thành';
  //     } else if (now.isAfter(orderTime) && now.isBefore(endTime)) {
  //       status = 'Đang thực hiện';
  //     } else {
  //       status = _statuses[_random.nextInt(_statuses.length)];
  //     }
  //
  //     orders.add({
  //       'id': 'order-${now.millisecondsSinceEpoch}-$i',
  //       'service': service,
  //       'customerName': customerName,
  //       'startTime': orderTime,
  //       'endTime': endTime,
  //       'timeDisplay': '${timeFormat.format(orderTime)} - ${timeFormat.format(endTime)}',
  //       'rating': rating,
  //       'commission': commission,
  //       'status': status,
  //     });
  //   }
  //
  //   // Sort by start time
  //   orders.sort((a, b) => (a['startTime'] as DateTime).compareTo(b['startTime'] as DateTime));
  //
  //   return orders;
  // }
  //
  static Future<List<Map<String, dynamic>>> getTodayOrders(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('${baseUrl}/api/v1/admin/appointment/today?userId=$userId'),
        headers: {
          'Content-Type': 'application/json',
          // Add authorization header if needed
        },
      );

      if (response.statusCode == 200) {
        print("Response body: ${response.body}");
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['appointments'] ?? []);
      } else {
        throw Exception('Failed to fetch today\'s orders');
      }
    } catch (e) {
      print('Error fetching today\'s orders: $e');
      return [];
    }
  }
  static Future<Map<String, List<Map<String, dynamic>>>> getMonthlyHistory() async {
    await Future.delayed(const Duration(milliseconds: 1000));

    final now = DateTime.now();
    final dateFormat = DateFormat('dd/MM/yyyy');
    final result = <String, List<Map<String, dynamic>>>{};

    // Generate data for current month and previous 3 months
    for (int monthOffset = 0; monthOffset >= -3; monthOffset--) {
      final targetMonth = DateTime(now.year, now.month + monthOffset);
      final monthKey = DateFormat('MM/yyyy').format(targetMonth);

      // Random number of work days in the month (15-23)
      final workDays = 15 + _random.nextInt(8);

      // Base salary (7-10 million VND)
      final baseSalary = 7000000 + _random.nextInt(3000000);

      // Monthly orders
      final monthlyOrders = <Map<String, dynamic>>[];
      var totalCommission = 0;

      // Generate orders for each work day
      for (int day = 1; day <= workDays; day++) {
        // Skip some days randomly
        if (_random.nextDouble() > 0.8) continue;

        final date = DateTime(targetMonth.year, targetMonth.month, day);

        // Skip future dates
        if (date.isAfter(now)) continue;

        // Generate 1-5 orders per day
        final dailyOrderCount = 1 + _random.nextInt(5);

        for (int i = 0; i < dailyOrderCount; i++) {
          final startHour = 8 + _random.nextInt(10);
          final startMinute = _random.nextInt(60);
          final orderTime = DateTime(date.year, date.month, date.day, startHour, startMinute);

          final durationMinutes = 30 + _random.nextInt(90);
          final endTime = orderTime.add(Duration(minutes: durationMinutes));

          final service = _services[_random.nextInt(_services.length)];
          final rating = 1 + _random.nextInt(5);
          final commission = 50000 + _random.nextInt(150000);

          totalCommission += commission;

          monthlyOrders.add({
            'id': 'order-${date.millisecondsSinceEpoch}-$i',
            'date': date,
            'dateDisplay': dateFormat.format(date),
            'service': service,
            'startTime': orderTime,
            'endTime': endTime,
            'timeDisplay': '${DateFormat('HH:mm').format(orderTime)} - ${DateFormat('HH:mm').format(endTime)}',
            'rating': rating,
            'commission': commission,
            'status': 'Hoàn thành', // All past orders are completed
          });
        }
      }

      // Sort by date and time
      monthlyOrders.sort((a, b) {
        final dateComparison = (b['date'] as DateTime).compareTo(a['date'] as DateTime);
        if (dateComparison != 0) return dateComparison;
        return (a['startTime'] as DateTime).compareTo(b['startTime'] as DateTime);
      });

      // Create the month summary
      result[monthKey] = [
        // First element is the month summary
        {
          'isSummary': true,
          'month': monthKey,
          'workDays': workDays,
          'totalOrders': monthlyOrders.length,
          'baseSalary': baseSalary,
          'totalCommission': totalCommission,
          'totalEarnings': baseSalary + totalCommission,
        },
        // Add all the orders
        ...monthlyOrders,
      ];
    }

    return result;
  }
  static Future<List<Map<String, dynamic>>> getShiftServices(String shift) async {
    await Future.delayed(const Duration(milliseconds: 500));

    // Mock data for services in different shifts
    final services = <Map<String, dynamic>>[
      {
        'id': 1,
        'name': 'Facial Cơ Bản',
        'duration': 60,
        'price': 450000,
      },
      {
        'id': 2,
        'name': 'Massage Thư Giãn',
        'duration': 90,
        'price': 600000,
      },
      {
        'id': 3,
        'name': 'Tẩy Da Chết',
        'duration': 30,
        'price': 350000,
      },
      {
        'id': 4,
        'name': 'Làm Trắng Da',
        'duration': 75,
        'price': 800000,
      },
    ];

    return services;
  }
}