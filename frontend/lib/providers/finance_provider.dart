import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../models/debt.dart';
import '../models/transaction.dart';

class FinanceProvider extends ChangeNotifier {
  List<Debt> _debts = [];
  List<Transaction> _transactions = [];
  List<Transaction> _recurringTransactions = [];
  bool _isLoading = false;
  String? _error;
  String? _householdId;

  List<Debt> get debts => _debts;
  List<Transaction> get transactions => _transactions;
  List<Transaction> get recurringTransactions => _recurringTransactions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setHouseholdId(String? id) {
    if (_householdId != id && id != null) {
      _householdId = id;
      fetchAll();
    }
  }

  Future<void> fetchAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        ApiClient.instance.dio.get('/debts/'),
        ApiClient.instance.dio.get('/transactions/'),
        ApiClient.instance.dio.get('/transactions/recurring/'),
      ]);
      _debts = (results[0].data as List<dynamic>)
          .map((d) => Debt.fromJson(d as Map<String, dynamic>))
          .toList();
      _transactions = (results[1].data as List<dynamic>)
          .map((t) => Transaction.fromJson(t as Map<String, dynamic>))
          .toList();
      _recurringTransactions = (results[2].data as List<dynamic>)
          .map((t) => Transaction.fromJson(t as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _error = (e.error as ApiException?)?.message ?? e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addTransaction(Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();
    try {
      await ApiClient.instance.dio.post('/transactions/', data: data);
      await fetchAll();
    } on DioException catch (e) {
      _error = (e.error as ApiException?)?.message ?? e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> editTransaction(String id, Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();
    try {
      await ApiClient.instance.dio.put('/transactions/$id/', data: data);
      await fetchAll();
    } on DioException catch (e) {
      _error = (e.error as ApiException?)?.message ?? e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteTransaction(String id) async {
    try {
      await ApiClient.instance.dio.delete('/transactions/$id/');
      _transactions = _transactions.where((t) => t.id != id).toList();
      _recurringTransactions = _recurringTransactions.where((t) => t.id != id).toList();
      notifyListeners();
      await fetchAll();
    } on DioException catch (e) {
      _error = (e.error as ApiException?)?.message ?? e.message;
      notifyListeners();
    }
  }

  Future<bool> canEditTransaction(String id) async {
    try {
      final resp = await ApiClient.instance.dio.get('/transactions/$id/can-edit/');
      return (resp.data as Map<String, dynamic>)['can_edit'] as bool;
    } on DioException {
      return false;
    }
  }

  Future<void> settleDebt({
    required String debtorId,
    required String creditorId,
    double? amount,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = <String, dynamic>{
        'debtor_id': debtorId,
        'creditor_id': creditorId,
      };
      if (amount != null) data['amount'] = amount;
      await ApiClient.instance.dio.post('/debts/settle/', data: data);
      await fetchAll();
    } on DioException catch (e) {
      _error = (e.error as ApiException?)?.message ?? e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
