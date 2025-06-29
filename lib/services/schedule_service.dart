import 'dart:convert';
import 'dart:math';
import 'package:employee_app/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class ScheduleService {
  static final Random _random = Random();
  static const String baseUrl = 'http://10.0.2.2:8080';

  static Future<List<Map<String, dynamic>>> getUserSchedule() async {
    try {
      final userId = AuthService.getCurrentUser()?['id'];
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/users-schedules/user/$userId/schedule'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> rawData = json.decode(response.body);
        print(response.body);

        final List<Map<String, dynamic>> schedules = rawData.map<Map<String, dynamic>>((item) {
          final String rawShift = item['shift'] ?? '';
          final RegExp regex = RegExp(r'^(.+?)\s*\(([^)]+)\)$');
          String shiftName = rawShift;

          String? checkInTime;
          String? checkOutTime;

          final match = regex.firstMatch(rawShift);
          if (match != null) {
            shiftName = match.group(1)!;
            final timeRange = match.group(2)!;
            final times = timeRange.split(' - ');
            if (times.length == 2) {
              checkInTime = times[0];
              checkOutTime = times[1];
            }
          }

          final dateObj = DateTime.parse(item['date']);
          final formattedDate = DateFormat('dd/MM/yyyy').format(dateObj);
          final weekdayFull = DateFormat('EEEE', 'vi_VN').format(dateObj);
          final weekday = _shortenVietnameseWeekday(weekdayFull);
          print('weekdayFull: $weekdayFull');
          print('Weekday: $weekday');
          return {
            'id': item['id'],
            'date': dateObj,
            'formattedDate': formattedDate,
            'weekday': weekday,
            'shift': shiftName,
            'checkInTime': checkInTime,
            'checkOutTime': checkOutTime,
            'status': item['status'],
          };
        }).toList();

        return schedules;
      } else {
        throw Exception('Failed to fetch user schedule');
      }
    } catch (e) {
      print('Error fetching schedule: $e');
      return [];
    }
  }

  static String _shortenVietnameseWeekday(String fullWeekday) {
    switch (fullWeekday.toLowerCase()) {
      case 'thứ hai':
        return 'Hai';
      case 'thứ ba':
        return 'Ba';
      case 'thứ tư':
        return 'Tư';
      case 'thứ năm':
        return 'Năm';
      case 'thứ sáu':
        return 'Sáu';
      case 'thứ bảy':
        return 'Bảy';
      case 'chủ nhật':
        return 'CN';
      default:
        return fullWeekday;
    }
  }



  static Future<Map<String, dynamic>> getTodayStatus(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('${baseUrl}/api/v1/work-status/today?userId=$userId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'hasShift': data['hasShift'],
          'schedules': data['schedules'],
          'currentStatus': data['currentStatus'],
          'message': data['message'],
        };
      } else {
        throw Exception('Failed to fetch work status');
      }
    } catch (e) {
      return {
        'hasShift': false,
        'message': 'Không thể lấy trạng thái làm việc',
        'status': 'Error',
      };
    }
  }
}