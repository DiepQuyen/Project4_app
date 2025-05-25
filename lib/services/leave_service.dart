// lib/services/leave_service.dart
import 'dart:async';

class LeaveService {
  static final List<Map<String, dynamic>> _leaveRequests = [];

  // Get all leave requests for the current user
  static Future<List<Map<String, dynamic>>> getLeaveRequests() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return List.from(_leaveRequests);
  }

  // Submit a new leave request
  static Future<Map<String, dynamic>> submitLeaveRequest({
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    required String type,
  }) async {
    await Future.delayed(const Duration(seconds: 1));

    final newRequest = {
      'id': 'leave-${DateTime.now().millisecondsSinceEpoch}',
      'startDate': startDate,
      'endDate': endDate,
      'reason': reason,
      'type': type,
      'status': 'pending',
      'submittedAt': DateTime.now(),
      'daysCount': endDate.difference(startDate).inDays + 1,
    };

    _leaveRequests.add(newRequest);

    return {
      'success': true,
      'message': 'Đã gửi yêu cầu nghỉ phép',
      'request': newRequest,
    };
  }

  // Cancel a leave request
  static Future<Map<String, dynamic>> cancelLeaveRequest(String requestId) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final index = _leaveRequests.indexWhere((req) => req['id'] == requestId);
    if (index != -1 && _leaveRequests[index]['status'] == 'pending') {
      _leaveRequests.removeAt(index);
      return {
        'success': true,
        'message': 'Đã hủy yêu cầu nghỉ phép',
      };
    }

    return {
      'success': false,
      'message': 'Không thể hủy yêu cầu này',
    };
  }

  // For demo purposes - simulate manager approving/rejecting requests
  static Future<void> simulateManagerAction() async {
    await Future.delayed(const Duration(seconds: 5));

    for (var request in _leaveRequests) {
      if (request['status'] == 'pending') {
        // Randomly approve or reject
        request['status'] = DateTime.now().millisecond % 3 == 0 ? 'rejected' : 'approved';
      }
    }
  }
  static bool isOnLeaveForDate(DateTime date) {
    final today = DateTime(date.year, date.month, date.day);

    for (var request in _leaveRequests) {
      if (request['status'] == 'approved') {
        final startDate = DateTime(
          (request['startDate'] as DateTime).year,
          (request['startDate'] as DateTime).month,
          (request['startDate'] as DateTime).day,
        );
        final endDate = DateTime(
          (request['endDate'] as DateTime).year,
          (request['endDate'] as DateTime).month,
          (request['endDate'] as DateTime).day,
        );

        if (today.isAtSameMomentAs(startDate) ||
            today.isAtSameMomentAs(endDate) ||
            (today.isAfter(startDate) && today.isBefore(endDate))) {
          return true;
        }
      }
    }

    return false;
  }
}