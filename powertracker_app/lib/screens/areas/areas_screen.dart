import 'package:flutter/material.dart';

import '../../core/storage/token_storage.dart';
import '../../services/api_service.dart';

class AreasScreen extends StatefulWidget {
  const AreasScreen({super.key});

  @override
  State<AreasScreen> createState() => _AreasScreenState();
}

class _AreasScreenState extends State<AreasScreen> {
  final _apiService = ApiService();
  final _tokenStorage = TokenStorage();

  List<Map<String, dynamic>> _areas = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAreas();
  }

  Future<void> _loadAreas() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _tokenStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('Please log in again to view areas.');
      }

      final areas = await _apiService.getAreas(token);
      if (!mounted) return;

      setState(() {
        _areas = areas
            .whereType<Map>()
            .map((area) => Map<String, dynamic>.from(area))
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
      appBar: AppBar(title: const Text('Areas')),
      body: RefreshIndicator(
        onRefresh: _loadAreas,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _MessageState(
        message: _error!,
        actionLabel: 'Try again',
        onAction: _loadAreas,
      );
    }

    if (_areas.isEmpty) {
      return const _MessageState(message: 'No areas are available.');
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _areas.length,
      separatorBuilder: (_, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _AreaCard(area: _areas[index]),
    );
  }
}

class _AreaCard extends StatelessWidget {
  final Map<String, dynamic> area;

  const _AreaCard({required this.area});

  @override
  Widget build(BuildContext context) {
    final name = area['name']?.toString() ?? 'Unknown area';
    final region = area['region']?.toString() ?? 'Unknown region';
    final count = int.tryParse(
          area['active_outage_count']?.toString() ?? '',
        ) ??
        0;
    final hasOutage = count > 0;
    final statusColor = hasOutage
        ? const Color(0xFFE53935)
        : const Color(0xFF43A047);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 8,
        ),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.12),
          child: Icon(Icons.location_on_outlined, color: statusColor),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(region),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: statusColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              count == 1 ? 'active outage' : 'active outages',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  const _MessageState({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

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
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: onAction,
                      icon: const Icon(Icons.refresh),
                      label: Text(actionLabel!),
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
