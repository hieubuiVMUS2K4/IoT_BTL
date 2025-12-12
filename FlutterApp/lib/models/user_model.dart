import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

/// Enum định nghĩa các role trong hệ thống
enum UserRole {
  admin,   // Toàn quyền: quản lý user, xem reports, điều khiển thiết bị, cấu hình WiFi
  user,    // Quyền cơ bản: xem dashboard, điều khiển thiết bị, xem reports cá nhân
  viewer,  // Chỉ xem: xem dashboard, không điều khiển được
}

/// Extension để chuyển đổi string <-> enum
extension UserRoleExtension on UserRole {
  String get value {
    switch (this) {
      case UserRole.admin:
        return 'admin';
      case UserRole.user:
        return 'user';
      case UserRole.viewer:
        return 'viewer';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Quản trị viên';
      case UserRole.user:
        return 'Người dùng';
      case UserRole.viewer:
        return 'Khách';
    }
  }

  static UserRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'viewer':
        return UserRole.viewer;
      default:
        return UserRole.user;
    }
  }
}

/// Class định nghĩa quyền hạn chi tiết
class UserPermissions {
  final bool canControlDevices;      // Điều khiển thiết bị (LED, Fan, Door)
  final bool canViewDashboard;       // Xem dashboard
  final bool canViewReports;         // Xem báo cáo
  final bool canExportReports;       // Xuất báo cáo
  final bool canManageUsers;         // Quản lý users
  final bool canConfigureWifi;       // Cấu hình WiFi ESP
  final bool canToggleSecurity;      // Bật/tắt chế độ an ninh

  const UserPermissions({
    this.canControlDevices = false,
    this.canViewDashboard = true,
    this.canViewReports = false,
    this.canExportReports = false,
    this.canManageUsers = false,
    this.canConfigureWifi = false,
    this.canToggleSecurity = false,
  });

  /// Factory để tạo permissions từ role
  factory UserPermissions.fromRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return const UserPermissions(
          canControlDevices: true,
          canViewDashboard: true,
          canViewReports: true,
          canExportReports: true,
          canManageUsers: true,
          canConfigureWifi: true,
          canToggleSecurity: true,
        );
      case UserRole.user:
        return const UserPermissions(
          canControlDevices: true,
          canViewDashboard: true,
          canViewReports: true,
          canExportReports: false,
          canManageUsers: false,
          canConfigureWifi: false,
          canToggleSecurity: true,
        );
      case UserRole.viewer:
        return const UserPermissions(
          canControlDevices: false,
          canViewDashboard: true,
          canViewReports: false,
          canExportReports: false,
          canManageUsers: false,
          canConfigureWifi: false,
          canToggleSecurity: false,
        );
    }
  }
}

@JsonSerializable()
class User {
  final String id;
  final String username;
  final String email;
  final String fullName;
  final String role; // admin, user, viewer
  final DateTime createdAt;
  final DateTime? lastLogin;
  final bool isActive;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    this.role = 'user',
    required this.createdAt,
    this.lastLogin,
    this.isActive = true,
  });

  /// Getter để lấy UserRole enum từ string
  UserRole get userRole => UserRoleExtension.fromString(role);

  /// Getter để lấy permissions dựa trên role
  UserPermissions get permissions => UserPermissions.fromRole(userRole);

  /// Kiểm tra nhanh các quyền
  bool get isAdmin => role == 'admin';
  bool get isViewer => role == 'viewer';
  bool get canControl => permissions.canControlDevices;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? fullName,
    String? role,
    DateTime? createdAt,
    DateTime? lastLogin,
    bool? isActive,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      isActive: isActive ?? this.isActive,
    );
  }
}

@JsonSerializable()
class UserCredential {
  final String username;
  final String password;

  UserCredential({
    required this.username,
    required this.password,
  });

  factory UserCredential.fromJson(Map<String, dynamic> json) =>
      _$UserCredentialFromJson(json);
  Map<String, dynamic> toJson() => _$UserCredentialToJson(this);
}
