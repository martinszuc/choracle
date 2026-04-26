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
      _currentMember ??= _household!.members.firstOrNull;
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

  Future<void> addMember(String name) async {
    final resp = await ApiClient.instance.dio.post('/members/', data: {'name': name});
    final newMember = Member.fromJson(resp.data as Map<String, dynamic>);
    await initialize();
    await selectMember(newMember);
  }

  Future<void> deleteMember(String id) async {
    await ApiClient.instance.dio.delete('/members/$id/');
    await initialize();
  }
}
