import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class AttendanceService {
  static const String baseUrl = 'http://10.0.2.2:8080';
  // Get network information
  static Future<Map<String, dynamic>> _getNetworkInfo() async {
    try {
      final connectivity = Connectivity();
      final connectivityResult = await connectivity.checkConnectivity();

      String connectionType = 'unknown';
      switch (connectivityResult) {
        case ConnectivityResult.wifi:
          connectionType = 'wifi';
          break;
        case ConnectivityResult.mobile:
          connectionType = 'mobile';
          break;
        default:
          connectionType = 'none';
      }

      return {
        'connectionType': connectionType,
        'timestamp': DateTime.now().toIso8601String(),
        'ipAddress': '192.168.1.${DateTime.now().second}', // Mocked IP for simulation
      };
    } catch (e) {
      print('Error getting network info: $e');
      return {
        'connectionType': 'unknown',
        'error': e.toString(),
      };
    }
  }

  // Get device information
  static Future<Map<String, dynamic>> _getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      Map<String, dynamic> deviceData = {};

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceData = {
          'deviceId': androidInfo.id,
          'brand': androidInfo.brand,
          'model': androidInfo.model,
          'version': androidInfo.version.release,
          'sdkInt': androidInfo.version.sdkInt,
          'manufacturer': androidInfo.manufacturer,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceData = {
          'deviceId': iosInfo.identifierForVendor,
          'name': iosInfo.name,
          'model': iosInfo.model,
          'systemName': iosInfo.systemName,
          'systemVersion': iosInfo.systemVersion,
        };
      }

      return deviceData;
    } catch (e) {
      print('Error getting device info: $e');
      return {
        'error': e.toString(),
        'deviceId': 'unknown-${DateTime.now().millisecondsSinceEpoch}',
      };
    }
  }

  // Fake check-in API call
  static Future<Map<String, dynamic>> checkIn() async {
    try {
      // Simulate network latency
      await Future.delayed(const Duration(seconds: 1));

      final networkInfo = await _getNetworkInfo();
      final deviceInfo = await _getDeviceInfo();

      // Log the data that would be sent to backend
      print('CHECK-IN REQUEST:');
      print('Network Info: $networkInfo');
      print('Device Info: $deviceInfo');

      // Simulate successful API response
      return {
        'success': true,
        'message': 'Điểm danh thành công',
        'timestamp': DateTime.now().toIso8601String(),
        'data': {
          'networkInfo': networkInfo,
          'deviceInfo': deviceInfo,
        }
      };
    } catch (e) {
      print('Check-in error: $e');
      return {
        'success': false,
        'message': 'Lỗi khi điểm danh: ${e.toString()}',
      };
    }
  }

  // Fake check-out API call
  static Future<Map<String, dynamic>> checkOut() async {
    try {
      // Simulate network latency
      await Future.delayed(const Duration(seconds: 1));

      final networkInfo = await _getNetworkInfo();
      final deviceInfo = await _getDeviceInfo();

      // Log the data that would be sent to backend
      print('CHECK-OUT REQUEST:');
      print('Network Info: $networkInfo');
      print('Device Info: $deviceInfo');

      // Simulate successful API response
      return {
        'success': true,
        'message': 'Check-out thành công',
        'timestamp': DateTime.now().toIso8601String(),
        'data': {
          'networkInfo': networkInfo,
          'deviceInfo': deviceInfo,
        }
      };
    } catch (e) {
      print('Check-out error: $e');
      return {
        'success': false,
        'message': 'Lỗi khi check-out: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> requestEarlyCheckout(String reason) async {
    try {
      final networkInfo = await _getNetworkInfo();
      final deviceInfo = await _getDeviceInfo();
      // Giả lập gửi yêu cầu về sếp
      print('EARLY CHECKOUT REQUEST:');
      print('Reason: $reason');
      print('Network Info: $networkInfo');
      print('Device Info: $deviceInfo');
      await Future.delayed(const Duration(seconds: 1));
      return {
        'success': true,
        'message': 'Đã gửi yêu cầu về sớm',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi gửi yêu cầu: ${e.toString()}',
      };
    }
  }
  static Future<Map<String, dynamic>> getTodayWorkStatus() async {
    try {
      // Get userId from current session
      final userId = AuthService.getCurrentUser()?['id'];
      if (userId == null) {
        return {'error': 'User not logged in', 'success': false};
      }

      final response = await http.get(
        Uri.parse('${baseUrl}/api/v1/work-status/today?userId=$userId'),
        // headers: await ApiConfig.getHeaders(),
      );

      if (response.statusCode == 200) {
        return {
          'data': json.decode(response.body),
          'success': true,
        };
      } else {
        return {
          'error': 'Failed to load work status: ${response.statusCode}',
          'success': false
        };
      }
    } catch (e) {
      return {'error': 'Exception when loading work status: $e', 'success': false};
    }
  }
}