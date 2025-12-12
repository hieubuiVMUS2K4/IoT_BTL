import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<User> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    
    try {
      _users = await _dbService.getUsers();
    } catch (e) {
      print('Error loading users: $e');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _showAddUserDialog() async {
    final formKey = GlobalKey<FormState>();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final emailController = TextEditingController();
    final fullNameController = TextEditingController();
    String selectedRole = 'user';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Thêm người dùng mới'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên đăng nhập',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập tên đăng nhập';
                      }
                      if (_users.any((u) => u.username == value)) {
                        return 'Tên đăng nhập đã tồn tại';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mật khẩu',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    validator: (value) {
                      if (value == null || value.length < 6) {
                        return 'Mật khẩu phải có ít nhất 6 ký tự';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (value) {
                      if (value == null || !value.contains('@')) {
                        return 'Email không hợp lệ';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Họ và tên',
                      prefixIcon: Icon(Icons.badge),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập họ tên';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Vai trò',
                      prefixIcon: Icon(Icons.admin_panel_settings),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'admin', child: Text('Quản trị viên')),
                      DropdownMenuItem(value: 'user', child: Text('Người dùng')),
                      DropdownMenuItem(value: 'viewer', child: Text('Khách')),
                    ],
                    onChanged: (value) {
                      setDialogState(() => selectedRole = value!);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        final newUser = User(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          username: usernameController.text,
          email: emailController.text,
          fullName: fullNameController.text,
          role: selectedRole,
          createdAt: DateTime.now(),
        );

        await _dbService.saveUser(newUser);
        await _dbService.saveUserCredentials(
          newUser.id,
          UserCredential(
            username: usernameController.text,
            password: passwordController.text,
          ),
        );

        _showSuccess('Đã thêm người dùng ${newUser.username}');
        _loadUsers();
      } catch (e) {
        _showError('Lỗi thêm người dùng: $e');
      }
    }
  }

  Future<void> _editUserRole(User user) async {
    String selectedRole = user.role;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Đổi vai trò: ${user.username}'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('Quản trị viên'),
                subtitle: const Text('Toàn quyền'),
                value: 'admin',
                groupValue: selectedRole,
                onChanged: (value) {
                  setDialogState(() => selectedRole = value!);
                },
              ),
              RadioListTile<String>(
                title: const Text('Người dùng'),
                subtitle: const Text('Điều khiển thiết bị, xem báo cáo'),
                value: 'user',
                groupValue: selectedRole,
                onChanged: (value) {
                  setDialogState(() => selectedRole = value!);
                },
              ),
              RadioListTile<String>(
                title: const Text('Khách'),
                subtitle: const Text('Chỉ xem dashboard'),
                value: 'viewer',
                groupValue: selectedRole,
                onChanged: (value) {
                  setDialogState(() => selectedRole = value!);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, selectedRole),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (result != null && result != user.role) {
      try {
        final updatedUser = user.copyWith(role: result);
        await _dbService.updateUser(updatedUser);
        _showSuccess('Đã cập nhật vai trò cho ${user.username}');
        _loadUsers();
      } catch (e) {
        _showError('Lỗi cập nhật: $e');
      }
    }
  }

  Future<void> _toggleUserActive(User user) async {
    final newStatus = !user.isActive;
    final action = newStatus ? 'kích hoạt' : 'vô hiệu hóa';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận $action'),
        content: Text('Bạn có muốn $action tài khoản ${user.username}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action.toUpperCase()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final updatedUser = user.copyWith(isActive: newStatus);
        await _dbService.updateUser(updatedUser);
        _showSuccess('Đã $action tài khoản ${user.username}');
        _loadUsers();
      } catch (e) {
        _showError('Lỗi: $e');
      }
    }
  }

  Future<void> _deleteUser(User user) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (user.id == authProvider.currentUser?.id) {
      _showError('Không thể xóa tài khoản đang đăng nhập');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa tài khoản ${user.username}?\n'
            'Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dbService.deleteUser(user.id);
        _showSuccess('Đã xóa tài khoản ${user.username}');
        _loadUsers();
      } catch (e) {
        _showError('Lỗi xóa: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final canManage = authProvider.currentUser?.permissions.canManageUsers ?? false;

    if (!canManage) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quản lý người dùng')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Bạn không có quyền truy cập tính năng này'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý người dùng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddUserDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Thêm'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Chưa có người dùng nào'),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadUsers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return _UserCard(
                        user: user,
                        currentUserId: authProvider.currentUser?.id,
                        onEditRole: () => _editUserRole(user),
                        onToggleActive: () => _toggleUserActive(user),
                        onDelete: () => _deleteUser(user),
                      ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.1);
                    },
                  ),
                ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final User user;
  final String? currentUserId;
  final VoidCallback onEditRole;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.currentUserId,
    required this.onEditRole,
    required this.onToggleActive,
    required this.onDelete,
  });

  Color _getRoleColor() {
    switch (user.role) {
      case 'admin':
        return Colors.purple;
      case 'viewer':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  IconData _getRoleIcon() {
    switch (user.role) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'viewer':
        return Icons.visibility;
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCurrentUser = user.id == currentUserId;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getRoleColor().withOpacity(0.2),
                  child: Icon(_getRoleIcon(), color: _getRoleColor()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            user.fullName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          if (isCurrentUser) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Bạn',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                          if (!user.isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Đã khóa',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '@${user.username}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getRoleColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    user.userRole.displayName,
                    style: TextStyle(
                      color: _getRoleColor(),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.email, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(user.email, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 16),
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  user.lastLogin != null
                      ? 'Đăng nhập: ${_formatDateTime(user.lastLogin!)}'
                      : 'Chưa đăng nhập',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (!isCurrentUser) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onEditRole,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Vai trò'),
                  ),
                  TextButton.icon(
                    onPressed: onToggleActive,
                    icon: Icon(
                      user.isActive ? Icons.lock : Icons.lock_open,
                      size: 18,
                    ),
                    label: Text(user.isActive ? 'Khóa' : 'Mở khóa'),
                  ),
                  TextButton.icon(
                    onPressed: onDelete,
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Xóa'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
