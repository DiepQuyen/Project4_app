import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class ScheduleService {
  static final Random _random = Random();
  static const String baseUrl = 'http://10.0.2.2:8080';

  static Future<List<Map<String, dynamic>>> getUserSchedule() async {
    await Future.delayed(const Duration(milliseconds: 800));

    final now = DateTime.now();
    final schedules = <Map<String, dynamic>>[];

    // Generate schedule for the next 14 days
    for (int i = 0; i < 14; i++) {
      final date = DateTime(now.year, now.month, now.day + i);
      final weekday = date.weekday;

      // Skip some days randomly to simulate days off
      if (_random.nextDouble() > 0.8 || (weekday == DateTime.saturday && _random.nextBool())) {
        continue;
      }

      // Determine shift(s)
      List<String> shifts = [];
      if (weekday == 1 || weekday == 3 || weekday == 5) { // Mon, Wed, Fri
        shifts = _random.nextBool() ? ['Morning'] : ['Afternoon', 'Evening'];
      } else if (weekday == 7) { // Sunday
        shifts = ['Morning', 'Afternoon'];
      } else if (weekday != 6) { // Not Saturday
        shifts = _random.nextBool() ? ['Morning'] : ['Afternoon'];
      }

      for (String shift in shifts) {
        String checkInTime;
        String checkOutTime;

        switch (shift) {
          case 'Morning':
            checkInTime = '08:00';
            checkOutTime = '12:00';
            break;
          case 'Afternoon':
            checkInTime = '13:00';
            checkOutTime = '17:00';
            break;
          case 'Evening':
            checkInTime = '18:00';
            checkOutTime = '22:00';
            break;
          default:
            checkInTime = '09:00';
            checkOutTime = '17:00';
        }

        // For past dates, add status
        String status = 'Scheduled';
        if (date.isBefore(DateTime(now.year, now.month, now.day))) {
          final statusOptions = ['On Time', 'Late', 'Absent'];
          final weights = [0.7, 0.2, 0.1]; // 70% on time, 20% late, 10% absent

          final rand = _random.nextDouble();
          if (rand < weights[0]) {
            status = 'On Time';
          } else if (rand < weights[0] + weights[1]) {
            status = 'Late';
          } else {
            status = 'Absent';
          }
        } else if (date.day == now.day) {
          // Today's status
          final currentHour = DateTime.now().hour;
          final shiftStartHour = int.parse(checkInTime.split(':')[0]);
          final shiftEndHour = int.parse(checkOutTime.split(':')[0]);

          if (currentHour >= shiftStartHour && currentHour < shiftEndHour) {
            status = 'Working';
          } else if (currentHour >= shiftEndHour) {
            status = _random.nextDouble() > 0.2 ? 'On Time' : 'Late';
          } else {
            status = 'Scheduled';
          }
        }

        schedules.add({
          'id': schedules.length + 1,
          'date': date,
          'formattedDate': DateFormat('dd/MM/yyyy').format(date),
          'weekday': DateFormat('EEEE').format(date),
          'shift': shift,
          'checkInTime': checkInTime,
          'checkOutTime': checkOutTime,
          'status': status,
          'isActive': true,
        });
      }
    }

    return schedules;
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