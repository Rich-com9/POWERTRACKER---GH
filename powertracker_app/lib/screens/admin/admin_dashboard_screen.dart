import 'package:flutter/material.dart';

import '../../core/storage/token_storage.dart';
import '../../services/api_service.dart';
import 'admin_outages_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _apiService = ApiService();
  final _tokenStorage = TokenStorage();

  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _tokenStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('Please log in again to view the admin dashboard.');
      }

      final data = await _apiService.getAdminDashboard(token);
      if (!mounted) return;
      setState(() {
        _data = data;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin dashboard')),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _MessageState(message: _error!, onRetry: _loadDashboard);
    }

    final data = _data!;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.fact_check_outlined),
            title: const Text('Review outage reports'),
            subtitle: const Text('Inspect and reject false reports'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminOutagesScreen(),
                ),
              );
            },
          ),
        ),
        _Metric(label: 'Users', value: data['users']),
        _Metric(label: 'Areas', value: data['areas']),
        _Metric(label: 'Total outages', value: data['total_outages']),
        _Metric(label: 'Active outages', value: data['active_outages']),
        _Metric(label: 'Restored outages', value: data['restored_outages']),
        _Metric(label: 'Outages today', value: data['outages_today']),
        _Metric(label: 'Confirmations', value: data['total_confirmations']),
        _Metric(label: 'Saved areas', value: data['saved_areas']),
        _Metric(label: 'Unread notifications', value: data['unread_notifications']),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final dynamic value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(label),
        trailing: Text(
          '${value ?? 0}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
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
