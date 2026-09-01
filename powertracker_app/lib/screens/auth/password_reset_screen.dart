import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key});

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _apiService = ApiService();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  Future<void> _requestReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await _apiService.requestPasswordReset(email);
      if (!mounted) return;
      setState(() => _emailSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check your email for reset instructions.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmReset() async {
    if (_passwordController.text != _confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _apiService.confirmPasswordReset(
        email: _emailController.text.trim(),
        code: _codeController.text.trim(),
        newPassword: _passwordController.text,
        confirmPassword: _confirmController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset successfully.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Account email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : _requestReset,
              child: const Text('Send reset email'),
            ),
            if (_emailSent) ...[
              const SizedBox(height: 28),
              const Text('Enter the six-digit code from the email.'),
              const SizedBox(height: 12),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Six-digit code',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isLoading ? null : _confirmReset,
                child: const Text('Reset password'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}