import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = 'http://10.0.2.2:8080';
  static const String loginEndpoint = '/api/v1/userDetail/login';

  static String? _token;
  static Map<String, dynamic>? _currentUser;

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    if (_token != null && _currentUser != null) {
      return true;
    }

    // Try to get token from storage
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString('auth_token');
    final storedUser = prefs.getString('user_data');

    if (storedToken != null && storedUser != null) {
      _token = storedToken;
      _currentUser = jsonDecode(storedUser);
      return true;
    }

    return false;
  }

  // Login method
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$loginEndpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['status'] == 'SUCCESS') {
        // Store token and user data
        _token = responseData['data']['token'];
        _currentUser = responseData['data']['user'];
        // log the user in
        print('Login successful: $_currentUser');

        // Save to storage
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('auth_token', _token!);
        prefs.setString('user_data', jsonEncode(_currentUser));

        // Map user data to the format expected by the app
        final mappedUser = {
          'name': _currentUser!['fullName'],
          'username': _currentUser!['email'],
          'avatar': _currentUser!['imageUrl'] ?? 'https://cdn.pixabay.com/photo/2023/02/18/11/00/icon-7797704_1280.png',
        };

        return {
          'success': true,
          'message': responseData['message'] ?? 'Đăng nhập thành công',
          'user': mappedUser,
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Đăng nhập thất bại',
        };
      }
    } catch (e) {
      print("Login error: ${e.toString()}");
      return {
        'success': false,
        'message': 'Lỗi kết nối tới máy chủ',
      };
    }
  }

  // Get current user data
  static Map<String, dynamic>? getCurrentUser() {
    if (_currentUser != null) {
      return _currentUser;
    }
    return null;
  }

  // Logout method
  static Future<void> logout() async {
    _token = null;
    _currentUser = null;

    // Clear from storage
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('auth_token');
    prefs.remove('user_data');
  }

  // Change password method
  static Future<Map<String, dynamic>> changePassword(String oldPass, String newPass) async {
    // This would need to be updated to connect to a real password change endpoint
    await Future.delayed(const Duration(seconds: 1));
    return {
      'success': true,
      'message': 'Đổi mật khẩu thành công',
    };
  }
}