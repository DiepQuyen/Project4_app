import 'dart:async';
import 'package:intl/intl.dart';

class SalaryService {
  // Mock salary calculation service
  static Future<Map<String, dynamic>> getEstimatedSalary() async {
    await Future.delayed(const Duration(milliseconds: 800));

    final now = DateTime.now();
    final workDays = 22; // Typical work days in a month
    final workedDays = 18; // Sample data
    final totalHours = 145.5; // Sample data
    final overtimeHours = 9.5; // Sample data

    // Base calculations
    const baseSalary = 8000000.0; // 8 million VND
    const hourlyRate = 50000.0; // 50k VND per hour

    // Estimated salary calculation
    final baseSalaryPortion = baseSalary * (workedDays / workDays);
    final overtimePay = overtimeHours * hourlyRate;
    final totalSalary = baseSalaryPortion + overtimePay;

    // Format currency
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

    return {
      'baseSalary': baseSalary,
      'workedDays': workedDays,
      'totalWorkdays': workDays,
      'totalHours': totalHours,
      'overtimeHours': overtimeHours,
      'overtimePay': overtimePay,
      'totalSalary': totalSalary,
      'formattedTotal': formatter.format(totalSalary),
      'month': '${now.month}/${now.year}',
    };
  }
}