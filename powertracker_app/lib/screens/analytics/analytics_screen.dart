import 'package:flutter/material.dart';

import '../../core/storage/token_storage.dart';
import '../../services/api_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _apiService = ApiService();
  final _tokenStorage = TokenStorage();

  Map<String, dynamic>? _analytics;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _tokenStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('Please log in again to view analytics.');
      }

      final analytics = await _apiService.getAnalytics(token);
      if (!mounted) return;

      setState(() {
        _analytics = analytics;
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
      appBar: AppBar(title: const Text('Outage analytics')),
      body: RefreshIndicator(
        onRefresh: _loadAnalytics,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _MessageState(message: _error!, onRetry: _loadAnalytics);
    }

    final data = _analytics!;
    final average = data['average_outage_duration_hours'];
    final averageText = average is num
        ? '${average.toStringAsFixed(1)} hours'
        : 'Not available';
    final area = data['most_affected_area']?.toString() ?? 'Not available';
    final areaCount = data['most_affected_area_count']?.toString() ?? '0';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _MetricCard(
          icon: Icons.warning_amber_rounded,
          label: 'Active outages',
          value: '${data['active_outages'] ?? 0}',
          color: const Color(0xFFE53935),
        ),
        _MetricCard(
          icon: Icons.check_circle_outline,
          label: 'Restored outages',
          value: '${data['restored_outages'] ?? 0}',
          color: const Color(0xFF43A047),
        ),
        _MetricCard(
          icon: Icons.timer_outlined,
          label: 'Average outage duration',
          value: averageText,
          color: const Color(0xFF1976D2),
        ),
        _MetricCard(
          icon: Icons.location_on_outlined,
          label: 'Most affected area',
          value: '$area ($areaCount)',
          color: const Color(0xFFFF8F00),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(label, style: const TextStyle(color: Colors.black54)),
        subtitle: Text(
          value,
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
