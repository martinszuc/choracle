import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../models/shopping_item.dart';
import '../models/favorite_item.dart';

class ShoppingProvider extends ChangeNotifier {
  List<ShoppingItem> _items = [];
  List<FavoriteItem> _favorites = [];
  bool _showAvatars = true;
  bool _hideChecked = false;
  bool _isLoading = false;
  String? _error;
  String? _householdId;

  List<ShoppingItem> get items => _items;
  List<FavoriteItem> get favorites => _favorites;
  bool get showAvatars => _showAvatars;
  bool get hideChecked => _hideChecked;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setHouseholdId(String? id) {
    if (_householdId != id && id != null) {
      _householdId = id;
      fetchItems();
      fetchFavorites();
    }
  }

  Future<void> fetchItems() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final resp = await ApiClient.instance.dio.get('/shopping-items/');
      _items = (resp.data as List<dynamic>)
          .map((i) => ShoppingItem.fromJson(i as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _error = (e.error as ApiException?)?.message ?? e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addItems(List<Map<String, dynamic>> itemsData) async {
    _isLoading = true;
    notifyListeners();
    try {
      await ApiClient.instance.dio.post('/shopping-items/', data: itemsData);
      await fetchItems();
    } on DioException catch (e) {
      _error = (e.error as ApiException?)?.message ?? e.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> togglePurchased(String itemId, {String? purchasedById, String? linkedTransactionId}) async {
    try {
      final data = <String, dynamic>{'purchased': true};
      if (purchasedById != null) data['purchased_by'] = purchasedById;
      if (linkedTransactionId != null) data['linked_transaction'] = linkedTransactionId;
      final resp = await ApiClient.instance.dio.put('/shopping-items/$itemId/', data: data);
      final updated = ShoppingItem.fromJson(resp.data as Map<String, dynamic>);
      _items = _items.map((i) => i.id == itemId ? updated : i).toList();
      notifyListeners();
    } on DioException catch (e) {
      _error = (e.error as ApiException?)?.message ?? e.message;
      notifyListeners();
    }
  }

  Future<void> deleteItem(String itemId) async {
    try {
      await ApiClient.instance.dio.delete('/shopping-items/$itemId/');
      _items = _items.where((i) => i.id != itemId).toList();
      notifyListeners();
    } on DioException catch (e) {
      _error = (e.error as ApiException?)?.message ?? e.message;
      notifyListeners();
    }
  }

  Future<void> fetchFavorites() async {
    try {
      final resp = await ApiClient.instance.dio.get('/favorite-items/');
      _favorites = (resp.data as List<dynamic>)
          .map((f) => FavoriteItem.fromJson(f as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } on DioException {
      // non-critical
    }
  }

  Future<void> addFavorite(String name) async {
    try {
      await ApiClient.instance.dio.post('/favorite-items/', data: {'name': name});
      await fetchFavorites();
    } on DioException catch (e) {
      _error = (e.error as ApiException?)?.message ?? e.message;
      notifyListeners();
    }
  }

  Future<void> deleteFavorite(String id) async {
    try {
      await ApiClient.instance.dio.delete('/favorite-items/$id/');
      _favorites = _favorites.where((f) => f.id != id).toList();
      notifyListeners();
    } on DioException catch (e) {
      _error = (e.error as ApiException?)?.message ?? e.message;
      notifyListeners();
    }
  }

  void setShowAvatars(bool value) {
    _showAvatars = value;
    notifyListeners();
  }

  void setHideChecked(bool value) {
    _hideChecked = value;
    notifyListeners();
  }
}
