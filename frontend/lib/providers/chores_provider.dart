import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../core/api_client.dart';
import '../models/chore.dart';
import '../models/default_chore.dart';
import '../models/member_stats.dart';

class ChoresProvider extends ChangeNotifier {
  List<Chore> _chores = [];
  List<DefaultChore> _defaultChores = [];
  MemberStats? _stats;
  bool _isLoading = false;
  String? _error;
  String? _householdId;

  List<Chore> get chores => _chores;
  List<DefaultChore> get defaultChores => _defaultChores;
  MemberStats? get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setHouseholdId(String? id) {
    if (_householdId != id && id != null) {
      _householdId = id;
      fetchChores();
      fetchDefaultChores();
    }
  }

  String _currentWeek() {
    final now = DateTime.now();
    final week = weekNumber(now);
    return '${now.year}-W${week.toString().padLeft(2, '0')}';
  }

  int weekNumber(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    final firstMonday = startOfYear.weekday <= 4
        ? startOfYear.subtract(Duration(days: startOfYear.weekday - 1))
        : startOfYear.add(Duration(days: 8 - startOfYear.weekday));
    final diff = date.difference(firstMonday).inDays;
    return (diff / 7).floor() + 1;
  }

  Future<void> fetchChores({String? week}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final w = week ?? _currentWeek();
      final resp = await ApiClient.instance.dio.get('/chores/', queryParameters: {'week': w});
      _chores = (resp.data as List<dynamic>)
          .map((c) => Chore.fromJson(c as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _error = (e.error as ApiException?)?.message ?? e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchDefaultChores() async {
    try {
      final resp = await ApiClient.instance.dio.get('/default-chores/');
      _defaultChores = (resp.data as List<dynamic>)
          .map((c) => DefaultChore.fromJson(c as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } on DioException {
      // non-critical, don't surface error
    }
  }

  Future<void> fetchStats(String memberId) async {
    try {
      final resp = await ApiClient.instance.dio.get('/stats/', queryParameters: {'member_id': memberId});
      _stats = MemberStats.fromJson(resp.data as Map<String, dynamic>);
      notifyListeners();
    } on DioException catch (e) {
      _error = (e.error as ApiException?)?.message ?? e.message;
      notifyListeners();
    }
  }

  Future<void> addChore(String name, String assignedToId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await ApiClient.instance.dio.post('/chores/', data: {
        'name': name,
        'assigned_to_id': assignedToId,
      });
      await fetchChores();
    } on DioException catch (e) {
      _error = (e.error as ApiException?)?.message ?? e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> completeChore(String choreId, String completedById) async {
    try {
      final resp = await ApiClient.instance.dio.put(
        '/chores/$choreId/complete/',
        data: {'completed_by': completedById},
      );
      final updated = Chore.fromJson(resp.data as Map<String, dynamic>);
      _chores = _chores.map((c) => c.id == choreId ? updated : c).toList();
      notifyListeners();
    } on DioException catch (e) {
      _error = (e.error as ApiException?)?.message ?? e.message;
      notifyListeners();
    }
  }

  Future<void> stealChore(String choreId, String memberId) async {
    try {
      final resp = await ApiClient.instance.dio.put(
        '/chores/$choreId/assign/',
        data: {'member_id': memberId},
      );
      final updated = Chore.fromJson(resp.data as Map<String, dynamic>);
      _chores = _chores.map((c) => c.id == choreId ? updated : c).toList();
      notifyListeners();
    } on DioException catch (e) {
      _error = (e.error as ApiException?)?.message ?? e.message;
      notifyListeners();
    }
  }

  Future<void> deleteChore(String choreId) async {
    try {
      await ApiClient.instance.dio.delete('/chores/$choreId/');
      _chores = _chores.where((c) => c.id != choreId).toList();
      notifyListeners();
    } on DioException catch (e) {
      _error = (e.error as ApiException?)?.message ?? e.message;
      notifyListeners();
    }
  }

  Future<void> addDefaultChore(String name, int frequencyDays, DateTime startDate, {String? assignedToId}) async {
    _isLoading = true;
    notifyListeners();
    try {
      await ApiClient.instance.dio.post('/default-chores/', data: {
        'name': name,
        'frequency_days': frequencyDays,
        'start_date': DateFormat('yyyy-MM-dd').format(startDate),
        // ignore: use_null_aware_elements
        if (assignedToId != null) 'assigned_to_id': assignedToId,
      });
      await fetchDefaultChores();
    } on DioException catch (e) {
      _error = (e.error as ApiException?)?.message ?? e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteDefaultChore(String id) async {
    try {
      await ApiClient.instance.dio.delete('/default-chores/$id/');
      _defaultChores = _defaultChores.where((c) => c.id != id).toList();
      notifyListeners();
    } on DioException catch (e) {
      _error = (e.error as ApiException?)?.message ?? e.message;
      notifyListeners();
    }
  }
}
