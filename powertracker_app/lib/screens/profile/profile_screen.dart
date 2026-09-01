import 'package:flutter/material.dart';

import '../../core/storage/token_storage.dart';
import '../../services/api_service.dart';
import '../admin/admin_dashboard_screen.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _apiService = ApiService();
  final _tokenStorage = TokenStorage();

  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _tokenStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('Please log in again to view your profile.');
      }

      final profile = await _apiService.getProfile(token);
      if (!mounted) return;

      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _logout() async {
    await _tokenStorage.clearTokens();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _editProfile() async {
    final profile = _profile;
    if (profile == null) return;

    final usernameController = TextEditingController(
      text: profile['username']?.toString() ?? '',
    );
    final nameController = TextEditingController(
      text: profile['name']?.toString() ?? '',
    );
    final emailController = TextEditingController(
      text: profile['email']?.toString() ?? '',
    );
    final phoneController = TextEditingController(
      text: profile['phone']?.toString() ?? '',
    );

    final values = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, [
              usernameController.text.trim(),
              nameController.text.trim(),
              emailController.text.trim(),
              phoneController.text.trim(),
            ]),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    usernameController.dispose();
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();

    if (values == null || values.length != 4) return;

    try {
      final token = await _tokenStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('Please log in again to update your profile.');
      }

      final updated = await _apiService.updateProfile(
        token: token,
        username: values[0],
        name: values[1],
        email: values[2],
        phone: values[3],
      );

      if (!mounted) return;
      setState(() => _profile = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _changePassword() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final values = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current password'),
              ),
              TextField(
                controller: newController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm new password'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, [
              currentController.text,
              newController.text,
              confirmController.text,
            ]),
            child: const Text('Update password'),
          ),
        ],
      ),
    );
    currentController.dispose();
    newController.dispose();
    confirmController.dispose();

    if (values == null || values.length != 3) return;

    try {
      final token = await _tokenStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('Please log in again to change your password.');
      }
      await _apiService.changePassword(
        token: token,
        currentPassword: values[0],
        newPassword: values[1],
        confirmPassword: values[2],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My profile')),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _MessageState(message: _error!, onRetry: _loadProfile);
    }

    final profile = _profile!;
    final name = profile['name']?.toString().trim() ?? '';
    final username = profile['username']?.toString() ?? '';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        CircleAvatar(
          radius: 42,
          backgroundColor: const Color(0xFFE8EAF6),
          child: Text(
            (name.isNotEmpty ? name : username).isEmpty
                ? '?'
                : (name.isNotEmpty ? name : username)[0].toUpperCase(),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3F51B5),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          name.isEmpty ? username : name,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        if (username.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('@$username', textAlign: TextAlign.center),
        ],
        const SizedBox(height: 28),
        _ProfileField(
          icon: Icons.email_outlined,
          label: 'Email',
          value: profile['email']?.toString() ?? 'Not provided',
        ),
        _ProfileField(
          icon: Icons.phone_outlined,
          label: 'Phone',
          value: profile['phone']?.toString().trim().isNotEmpty == true
              ? profile['phone'].toString()
              : 'Not provided',
        ),
        if (profile['is_staff'] == true) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminDashboardScreen(),
                ),
              );
            },
            icon: const Icon(Icons.admin_panel_settings_outlined),
            label: const Text('Open admin dashboard'),
          ),
        ],
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _editProfile,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit profile'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _changePassword,
          icon: const Icon(Icons.lock_reset_outlined),
          label: const Text('Change password'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
        ),
      ],
    );
  }
}

class _ProfileField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileField({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xFF3F51B5)),
      title: Text(label, style: const TextStyle(color: Colors.black54)),
      subtitle: Text(
        value,
        style: const TextStyle(fontSize: 16, color: Colors.black87),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _MessageState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
