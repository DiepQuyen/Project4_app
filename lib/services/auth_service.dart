import 'dart:async';

class AuthService {
  static final Map<String, String> _fakeUsers = {
    'employee1': '12345',
    'employee2': '12345',
  };

  static Map<String, dynamic> _userData(String username) => {
        'username': username,
        'name': username == 'employee1' ? 'John Doe' : 'Jane Smith',
        'avatar': username == 'employee1'
            ? 'https://randomuser.me/api/portraits/men/1.jpg'
            : 'https://randomuser.me/api/portraits/women/1.jpg',
      };

  static String? _currentUser;

  // Đăng nhập
  static Future<Map<String, dynamic>> login(String username, String password) async {
    await Future.delayed(const Duration(seconds: 1));
    if (_fakeUsers[username] == password) {
      _currentUser = username;
      return {
        'success': true,
        'user': _userData(username),
      };
    } else {
      return {'success': false, 'message': 'Sai tài khoản hoặc mật khẩu'};
    }
  }

  // Lấy thông tin tài khoản hiện tại
  static Future<Map<String, dynamic>?> getProfile() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (_currentUser != null) {
      return _userData(_currentUser!);
    }
    return null;
  }

  // Đổi mật khẩu (fake)
  static Future<Map<String, dynamic>> changePassword(String oldPass, String newPass) async {
    await Future.delayed(const Duration(seconds: 1));
    if (_currentUser == null) {
      return {'success': false, 'message': 'Chưa đăng nhập'};
    }
    if (_fakeUsers[_currentUser!] != oldPass) {
      return {'success': false, 'message': 'Mật khẩu cũ không đúng'};
    }
    _fakeUsers[_currentUser!] = newPass;
    return {'success': true, 'message': 'Đổi mật khẩu thành công'};
  }

  // Đăng xuất
  static Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _currentUser = null;
  }
}