import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  
  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentUser != null;

  // Kiểm tra session khi app khởi động
  Future<bool> checkSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentUser = await _authService.getCurrentUser();
      _isLoading = false;
      notifyListeners();
      return _currentUser != null;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Đăng nhập
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _authService.login(username, password);
      _isLoading = false;
      
      if (_currentUser == null) {
        _errorMessage = 'Tên đăng nhập hoặc mật khẩu không đúng';
        notifyListeners();
        return false;
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi đăng nhập: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // Đăng ký
  Future<bool> register({
    required String username,
    required String password,
    required String email,
    required String fullName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _authService.register(
        username: username,
        password: password,
        email: email,
        fullName: fullName,
      );
      
      _isLoading = false;
      
      if (_currentUser == null) {
        _errorMessage = 'Không thể đăng ký. Tên đăng nhập đã tồn tại.';
        notifyListeners();
        return false;
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi đăng ký: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // Đăng xuất
  Future<void> logout() async {
    await _authService.logout();
    _currentUser = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
