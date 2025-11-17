import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'database_service.dart';

class AuthService {
  static const String _keyCurrentUser = 'current_user';
  static const String _keyAuthToken = 'auth_token';
  
  final DatabaseService _db = DatabaseService();

  // Đăng nhập
  Future<User?> login(String username, String password) async {
    try {
      print('Attempting login for: $username');
      final users = await _db.getUsers();
      print('Found ${users.length} users');
      
      // Tìm user với username
      final user = users.firstWhere(
        (u) => u.username == username,
        orElse: () => throw Exception('User not found'),
      );
      
      print('User found: ${user.username}');

      // Kiểm tra password
      final credentials = await _db.getUserCredentials(user.id);
      print('Credentials: ${credentials?.username}, password match: ${credentials?.password == password}');
      
      if (credentials == null || credentials.password != password) {
        throw Exception('Invalid password');
      }

      // Cập nhật last login
      final updatedUser = user.copyWith(lastLogin: DateTime.now());
      await _db.updateUser(updatedUser);

      // Lưu session
      await _saveSession(updatedUser);
      
      print('Login successful!');
      return updatedUser;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  // Đăng ký
  Future<User?> register({
    required String username,
    required String password,
    required String email,
    required String fullName,
  }) async {
    try {
      final users = await _db.getUsers();
      
      // Kiểm tra username đã tồn tại
      if (users.any((u) => u.username == username)) {
        throw Exception('Username already exists');
      }

      // Tạo user mới
      final newUser = User(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        username: username,
        email: email,
        fullName: fullName,
        role: 'user',
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );

      // Lưu user và credentials
      await _db.saveUser(newUser);
      await _db.saveUserCredentials(
        newUser.id,
        UserCredential(username: username, password: password),
      );

      // Lưu session
      await _saveSession(newUser);
      
      return newUser;
    } catch (e) {
      print('Register error: $e');
      return null;
    }
  }

  // Lấy user hiện tại từ session
  Future<User?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_keyCurrentUser);
      
      if (userJson == null) return null;
      
      return User.fromJson(jsonDecode(userJson));
    } catch (e) {
      print('Get current user error: $e');
      return null;
    }
  }

  // Lưu session
  Future<void> _saveSession(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrentUser, jsonEncode(user.toJson()));
    await prefs.setString(_keyAuthToken, 'token_${user.id}');
  }

  // Đăng xuất
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCurrentUser);
    await prefs.remove(_keyAuthToken);
  }

  // Kiểm tra đã đăng nhập
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyAuthToken);
  }
}
