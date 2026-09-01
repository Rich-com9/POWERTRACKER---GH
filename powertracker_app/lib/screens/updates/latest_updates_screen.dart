import 'package:flutter/material.dart';

import '../../core/storage/token_storage.dart';
import '../../services/api_service.dart';

class LatestUpdatesScreen extends StatefulWidget {
  const LatestUpdatesScreen({super.key});

  @override
  State<LatestUpdatesScreen> createState() => _LatestUpdatesScreenState();
}

class _LatestUpdatesScreenState extends State<LatestUpdatesScreen> {
  final _apiService = ApiService();
  final _tokenStorage = TokenStorage();

  List<Map<String, dynamic>> _updates = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUpdates();
  }

  Future<void> _loadUpdates() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _tokenStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('Please log in again to view updates.');
      }

      final updates = await _apiService.getLatestUpdates(token);
      if (!mounted) return;

      setState(() {
        _updates = updates
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
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
      appBar: AppBar(title: const Text('Latest updates')),
      body: RefreshIndicator(
        onRefresh: _loadUpdates,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return _MessageState(message: _error!, onRetry: _loadUpdates);
    }

    if (_updates.isEmpty) {
      return const _MessageState(message: 'No updates yet.');
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _updates.length,
      separatorBuilder: (_, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _UpdateCard(update: _updates[index]),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  final Map<String, dynamic> update;

  const _UpdateCard({required this.update});

  @override
  Widget build(BuildContext context) {
    final updateType = update['update_type']?.toString() ?? 'update';
    final area = update['area_name']?.toString() ?? 'Unknown area';
    final title = update['title']?.toString() ?? 'Power update';
    final message = update['message']?.toString() ?? '';
    final createdAt = _formatDate(update['created_at']);

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: _colorFor(updateType).withValues(alpha: 0.12),
          child: Icon(_iconFor(updateType), color: _colorFor(updateType)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(area, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(message),
              ],
              const SizedBox(height: 8),
              Text(createdAt, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'restored':
        return Icons.power;
      case 'update':
        return Icons.campaign_outlined;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'restored':
        return const Color(0xFF2E7D32);
      case 'update':
        return const Color(0xFF3F51B5);
      default:
        return const Color(0xFFE53935);
    }
  }

  String _formatDate(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (parsed == null) return 'Recently';

    final hour = parsed.hour == 0 ? 12 : (parsed.hour > 12 ? parsed.hour - 12 : parsed.hour);
    final minute = parsed.minute.toString().padLeft(2, '0');
    final period = parsed.hour >= 12 ? 'PM' : 'AM';
    return '${parsed.day}/${parsed.month}/${parsed.year}  $hour:$minute $period';
  }
}

class _MessageState extends StatelessWidget {
  final String message;
  final Future<void> Function()? onRetry;

  const _MessageState({required this.message, this.onRetry});

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
                  if (onRetry != null) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
