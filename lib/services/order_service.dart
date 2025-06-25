import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class OrderService {
  static const String baseUrl = 'https://sparlex.up.railway.app';
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
  static Future<Map<String, List<Map<String, dynamic>>>> getMonthlyHistory(int userId) async {
    final url = Uri.parse('${baseUrl}/api/v1/services/monthly-history?userId=$userId');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);

      // Đảm bảo chỉ lấy phần data thực sự
      final data = jsonData['data'];
      if (data == null || data is! Map<String, dynamic>) {
        throw Exception('Phản hồi không hợp lệ từ API');
      }

      final Map<String, List<Map<String, dynamic>>> result = {};

      data.forEach((monthKey, listDynamic) {
        final List<Map<String, dynamic>> monthList = [];

        if (listDynamic is List) {
          for (var item in listDynamic) {
            if (item is Map<String, dynamic>) {
              try {
                if (item['date'] is String) {
                  item['date'] = DateTime.parse(item['date']);
                }
                if (item['startTime'] is String) {
                  item['startTime'] = DateTime.parse(item['startTime']);
                }
                if (item['endTime'] is String) {
                  item['endTime'] = DateTime.parse(item['endTime']);
                }
              } catch (e) {
                print('Lỗi parse ngày: $e');
              }
              monthList.add(item);
            }
          }
        }

        result[monthKey] = monthList;
      });

      return result;
    } else {
      throw Exception('❌ Failed to load monthly history: ${response.statusCode}');
    }
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