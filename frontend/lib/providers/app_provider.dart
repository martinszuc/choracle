import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../models/household.dart';
import '../models/member.dart';

const _kSelectedMemberId = 'selected_member_id';

class AppProvider extends ChangeNotifier {
  Household? _household;
  Member? _currentMember;
  bool _isLoading = false;
  String? _error;

  Household? get household => _household;
  Member? get currentMember => _currentMember;
  List<Member> get members => _household?.members ?? [];
  String? get householdId => _household?.id;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    try {
      final resp = await ApiClient.instance.dio.get('/household/');
      _household = Household.fromJson(resp.data as Map<String, dynamic>);

      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_kSelectedMemberId);
      if (savedId != null) {
        _currentMember = _household!.members.where((m) => m.id == savedId).firstOrNull;
      }
      // auto-select only when there's a single member; with multiple members
      // we want the user to explicitly pick who they are on first launch
      if (_currentMember == null && _household!.members.length == 1) {
        _currentMember = _household!.members.first;
      }
      _error = null;
    } on DioException catch (e) {
      _error = (e.error as ApiException?)?.message ?? e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectMember(Member member) async {
    _currentMember = member;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSelectedMemberId, member.id);
  }

  Future<bool> addMember(String name) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final resp = await ApiClient.instance.dio.post('/members/', data: {'name': name});
      final newMember = Member.fromJson(resp.data as Map<String, dynamic>);
      await initialize();
      await selectMember(newMember);
      return true;
    } on DioException catch (e) {
      _error = (e.error as ApiException?)?.message ?? e.message;
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteMember(String id) async {
    try {
      await ApiClient.instance.dio.delete('/members/$id/');
      await initialize();
    } on DioException catch (e) {
      _error = (e.error as ApiException?)?.message ?? e.message;
      notifyListeners();
    }
  }
}
