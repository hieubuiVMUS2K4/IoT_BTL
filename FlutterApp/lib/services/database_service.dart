import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/user_model.dart';

class DatabaseService {
  static const String _usersFile = 'users.json';
  static const String _credentialsFile = 'credentials.json';

  // Lấy đường dẫn thư mục documents
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  // File users
  Future<File> get _usersDbFile async {
    final path = await _localPath;
    return File('$path/$_usersFile');
  }

  // File credentials
  Future<File> get _credentialsDbFile async {
    final path = await _localPath;
    return File('$path/$_credentialsFile');
  }

  // Lấy tất cả users
  Future<List<User>> getUsers() async {
    try {
      final file = await _usersDbFile;
      
      if (!await file.exists()) {
        print('Users file not found, creating default user...');
        // Tạo user mặc định
        await _createDefaultUser();
        // Return default user directly
        return [
          User(
            id: '1',
            username: 'admin',
            email: 'admin@smarthome.com',
            fullName: 'Administrator',
            role: 'admin',
            createdAt: DateTime.now(),
          )
        ];
      }

      final contents = await file.readAsString();
      if (contents.isEmpty) {
        print('Users file empty, creating default user...');
        await _createDefaultUser();
        // Return default user directly
        return [
          User(
            id: '1',
            username: 'admin',
            email: 'admin@smarthome.com',
            fullName: 'Administrator',
            role: 'admin',
            createdAt: DateTime.now(),
          )
        ];
      }
      
      final List<dynamic> jsonData = jsonDecode(contents);
      final users = jsonData.map((json) => User.fromJson(json)).toList();
      print('Loaded ${users.length} users');
      
      return users;
    } catch (e) {
      print('Error reading users: $e');
      return [];
    }
  }

  // Lưu user
  Future<void> saveUser(User user) async {
    try {
      final file = await _usersDbFile;
      List<User> users = [];
      
      // Read existing users if file exists
      if (await file.exists()) {
        final contents = await file.readAsString();
        if (contents.isNotEmpty) {
          final List<dynamic> jsonData = jsonDecode(contents);
          users = jsonData.map((json) => User.fromJson(json)).toList();
        }
      }
      
      users.add(user);
      
      await file.writeAsString(
        jsonEncode(users.map((u) => u.toJson()).toList()),
      );
    } catch (e) {
      print('Error saving user: $e');
    }
  }

  // Cập nhật user
  Future<void> updateUser(User user) async {
    try {
      final users = await getUsers();
      final index = users.indexWhere((u) => u.id == user.id);
      
      if (index != -1) {
        users[index] = user;
        
        final file = await _usersDbFile;
        await file.writeAsString(
          jsonEncode(users.map((u) => u.toJson()).toList()),
        );
      }
    } catch (e) {
      print('Error updating user: $e');
    }
  }

  // Lấy credentials của user
  Future<UserCredential?> getUserCredentials(String userId) async {
    try {
      final file = await _credentialsDbFile;
      
      if (!await file.exists()) {
        return null;
      }

      final contents = await file.readAsString();
      final Map<String, dynamic> jsonData = jsonDecode(contents);
      
      if (jsonData.containsKey(userId)) {
        return UserCredential.fromJson(jsonData[userId]);
      }
      
      return null;
    } catch (e) {
      print('Error reading credentials: $e');
      return null;
    }
  }

  // Lưu credentials
  Future<void> saveUserCredentials(String userId, UserCredential credentials) async {
    try {
      final file = await _credentialsDbFile;
      
      Map<String, dynamic> allCredentials = {};
      
      if (await file.exists()) {
        final contents = await file.readAsString();
        allCredentials = jsonDecode(contents);
      }

      allCredentials[userId] = credentials.toJson();
      
      await file.writeAsString(jsonEncode(allCredentials));
    } catch (e) {
      print('Error saving credentials: $e');
    }
  }

  // Tạo user mặc định
  Future<void> _createDefaultUser() async {
    print('Creating default user...');
    final defaultUser = User(
      id: '1',
      username: 'admin',
      email: 'admin@smarthome.com',
      fullName: 'Administrator',
      role: 'admin',
      createdAt: DateTime.now(),
    );

    final defaultCredentials = UserCredential(
      username: 'admin',
      password: 'admin123',
    );

    await saveUser(defaultUser);
    await saveUserCredentials(defaultUser.id, defaultCredentials);
    print('Default user created: admin/admin123');
  }
}
