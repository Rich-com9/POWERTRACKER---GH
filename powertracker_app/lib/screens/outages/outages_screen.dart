import 'package:flutter/material.dart';

import '../../core/storage/token_storage.dart';
import '../../services/api_service.dart';

class OutagesScreen extends StatefulWidget {
  const OutagesScreen({super.key});

  @override
  State<OutagesScreen> createState() => _OutagesScreenState();
}

class _OutagesScreenState extends State<OutagesScreen> {
  final _apiService = ApiService();
  final _tokenStorage = TokenStorage();

  List<Map<String, dynamic>> _outages = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOutages();
  }

  Future<void> _loadOutages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _tokenStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('Please log in again to view outages.');
      }

      final outages = await _apiService.getAllOutages(token);
      if (!mounted) return;

      setState(() {
        _outages = outages
            .whereType<Map>()
            .map((outage) => Map<String, dynamic>.from(outage))
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
      appBar: AppBar(
        title: const Text('All outages'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadOutages,
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
        onAction: _loadOutages,
      );
    }

    if (_outages.isEmpty) {
      return const _MessageState(
        message: 'No outages have been reported.',
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _outages.length,
      separatorBuilder: (_, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _OutageCard(
        outage: _outages[index],
        onConfirmed: _loadOutages,
      ),
    );
  }
}

class _OutageCard extends StatelessWidget {
  final Map<String, dynamic> outage;
  final Future<void> Function() onConfirmed;

  const _OutageCard({
    required this.outage,
    required this.onConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    final status = outage['status']?.toString() ?? 'unknown';
    final area = outage['area_name']?.toString() ?? 'Unknown area';
    final type = outage['outage_type']?.toString() ?? 'unknown';
    final description = outage['description']?.toString().trim() ?? '';
    final confirmationCount = int.tryParse(
          outage['confirmations']?.toString() ?? '',
        ) ??
        0;
    final accurateVotes = int.tryParse(
          outage['accurate_votes']?.toString() ?? '',
        ) ??
        0;
    final inaccurateVotes = int.tryParse(
          outage['inaccurate_votes']?.toString() ?? '',
        ) ??
        0;
    final reportedAt = _formatDate(outage['reported_at']);
    final isActive = status == 'active';
    final statusColor = isActive ? const Color(0xFFE53935) : const Color(0xFF43A047);
    final outageId = int.tryParse(outage['id']?.toString() ?? '');

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    area,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status[0].toUpperCase() + status.substring(1),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${type[0].toUpperCase() + type.substring(1)} outage',
              style: const TextStyle(color: Colors.black54),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(description),
            ],
            const SizedBox(height: 14),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                const Icon(Icons.people_outline, size: 18, color: Colors.black54),
                Text(
                  '$confirmationCount ${confirmationCount == 1 ? 'confirmation' : 'confirmations'}',
                ),
                Text(
                  '$accurateVotes accurate • $inaccurateVotes inaccurate',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(width: 4),
                Text(
                  reportedAt,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
            if (isActive && outageId != null) ...[
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _confirmOutage(context, outageId),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Confirm outage'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _resolveOutage(context, outageId),
                    icon: const Icon(Icons.power),
                    label: const Text('Mark restored'),
                  ),
                ],
              ),
            ],
            if (outageId != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _verifyOutage(context, outageId),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Verify report'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmOutage(BuildContext context, int outageId) async {
    final token = await TokenStorage().getAccessToken();

    if (token == null || token.isEmpty || !context.mounted) return;

    try {
      await ApiService().confirmOutage(
        token: token,
        outageId: outageId,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Outage confirmed.')),
      );
      await onConfirmed();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _resolveOutage(BuildContext context, int outageId) async {
    final shouldResolve = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark outage as restored?'),
        content: const Text(
          'Only do this if power has returned in the affected area.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark restored'),
          ),
        ],
      ),
    );

    if (shouldResolve != true || !context.mounted) return;

    final token = await TokenStorage().getAccessToken();
    if (token == null || token.isEmpty || !context.mounted) return;

    try {
      await ApiService().resolveOutage(
        token: token,
        outageId: outageId,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Outage marked as restored.')),
      );
      await onConfirmed();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _verifyOutage(BuildContext context, int outageId) async {
    final vote = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify this report'),
        content: const Text('Does this outage report match what you experienced?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('May be inaccurate'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Report is accurate'),
          ),
        ],
      ),
    );

    if (vote == null || !context.mounted) return;

    final token = await TokenStorage().getAccessToken();
    if (token == null || token.isEmpty || !context.mounted) return;

    try {
      await ApiService().verifyOutage(
        token: token,
        outageId: outageId,
        isAccurate: vote,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification recorded.')),
      );
      await onConfirmed();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Date unavailable';

    final localDate = date.toLocal();
    final month = localDate.month.toString().padLeft(2, '0');
    final day = localDate.day.toString().padLeft(2, '0');
    final hour = localDate.hour.toString().padLeft(2, '0');
    final minute = localDate.minute.toString().padLeft(2, '0');
    return '${localDate.year}-$month-$day $hour:$minute';
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
