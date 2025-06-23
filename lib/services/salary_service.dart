import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class SalaryService {
  static const String baseUrl = 'http://10.0.2.2:8080';

  // Mock salary calculation service
  // static Future<Map<String, dynamic>> getEstimatedSalary(int userId) async {
  //   try {
  //     final response = await http.get(
  //       Uri.parse('${baseUrl}/api/v1/user/accounts/salary/estimated?userId=$userId'),
  //       headers: {
  //         'Content-Type': 'application/json',
  //         // Add authorization header if needed
  //       },
  //     );
  //
  //     if (response.statusCode == 200) {
  //       print("Response body: ${response.body}");
  //       final now = DateTime.now();
  //       final data = json.decode(response.body);
  //       final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
  //
  //       return {
  //         'baseSalary': data.baseSalary,
  //         'workedDays': data.workedDays,
  //         'totalWorkdays': data.workDays,
  //         'totalHours': data.totalHours,
  //         'totalTip': data.totalTip,
  //         'totalSalary': data.totalSalary,
  //         'formattedTotal': formatter.format(data.totalSalary),
  //         'month': '${now.month}/${now.year}',
  //       };
  //     } else {
  //       throw Exception('Failed to fetch today\'s orders');
  //     }
  //   } catch (e) {
  //     print('Error fetching today\'s orders: $e');
  //     return {};
  //   }
  // }

  static Future<Map<String, dynamic>> getEstimatedSalary(int userId) async {
    final now = DateTime.now();
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    try {
      final response = await http.get(
        Uri.parse('${baseUrl}/api/v1/user/accounts/salary/estimated?userId=$userId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        print("Response body salary: ${response.body}");
        final data = json.decode(response.body);

        return {
          'baseSalary': data['baseSalary'],
          'workedDays': data['workedDays'],
          'totalWorkdays': data['totalWorkdays'],
          'totalHours': data['totalHours'],
          'totalTip': data['totalTip'],
          'totalSalary': data['totalSalary'],
          'formattedTotal': formatter.format(data['totalSalary']),
          'month': '${now.month}/${now.year}',
        };
      } else {
        print('Failed to fetch salary data: ${response.statusCode}');
        return {
          'baseSalary': 0,
          'workedDays': 0,
          'totalWorkdays': 0,
          'totalHours': 0,
          'totalTip': 0,
          'totalSalary': 0,
          'formattedTotal': formatter.format(0),
          'month': '${now.month}/${now.year}',
        };
      }
    } catch (e) {
      print('Error fetching salary data: $e');
      return {
        'baseSalary': 0,
        'workedDays': 0,
        'totalWorkdays': 0,
        'totalHours': 0,
        'totalTip': 0,
        'totalSalary': 0,
        'formattedTotal': formatter.format(0),
        'month': '${now.month}/${now.year}',
      };
    }
  }
}