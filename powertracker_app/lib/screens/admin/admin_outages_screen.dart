import 'package:flutter/material.dart';

import '../../core/storage/token_storage.dart';
import '../../services/api_service.dart';

class AdminOutagesScreen extends StatefulWidget {
  const AdminOutagesScreen({super.key});

  @override
  State<AdminOutagesScreen> createState() => _AdminOutagesScreenState();
}

class _AdminOutagesScreenState extends State<AdminOutagesScreen> {
  final _apiService = ApiService();
  final _tokenStorage = TokenStorage();

  List<Map<String, dynamic>> _outages = [];
  bool _isLoading = true;
  String? _error;
  bool _isCreating = false;

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
        throw Exception('Please log in again to review outage reports.');
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

  Future<void> _rejectOutage(Map<String, dynamic> outage) async {
    final outageId = int.tryParse(outage['id']?.toString() ?? '');
    if (outageId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject this report?'),
        content: const Text('Rejected reports will no longer be treated as active outages.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject report'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final token = await _tokenStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('Please log in again to reject this report.');
      }

      await _apiService.rejectOutage(token: token, outageId: outageId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Outage report rejected.')),
      );
      await _loadOutages();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _respondToOutage(Map<String, dynamic> outage) async {
    final outageId = int.tryParse(outage['id']?.toString() ?? '');
    if (outageId == null) return;

    final messageController = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Respond to report'),
        content: TextField(
          controller: messageController,
          autofocus: true,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Message for the reporter',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = messageController.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('Send response'),
          ),
        ],
      ),
    );
    messageController.dispose();

    if (message == null) return;

    try {
      final token = await _tokenStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('Please log in again to respond to this report.');
      }

      await _apiService.createOutageUpdate(
        token: token,
        outageId: outageId,
        message: message,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Response sent to the reporter.')),
      );
      await _loadOutages();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _createScheduledOutage() async {
    final areas = await _loadAreas();
    if (!mounted || areas.isEmpty) return;

    final description = TextEditingController();
    final address = TextEditingController();
    final latitude = TextEditingController();
    final longitude = TextEditingController();
    final scheduled = TextEditingController();
    int? selectedArea;

    final values = await showDialog<List<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create scheduled notice'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: selectedArea,
                  decoration: const InputDecoration(labelText: 'Area'),
                  items: areas.map((area) => DropdownMenuItem<int>(
                    value: int.parse(area['id'].toString()),
                    child: Text('${area['name']} - ${area['region']}'),
                  )).toList(),
                  onChanged: (value) => setDialogState(() => selectedArea = value),
                ),
                TextField(controller: description, decoration: const InputDecoration(labelText: 'Notice')),
                TextField(controller: address, decoration: const InputDecoration(labelText: 'Location address')),
                TextField(controller: latitude, decoration: const InputDecoration(labelText: 'Latitude')),
                TextField(controller: longitude, decoration: const InputDecoration(labelText: 'Longitude')),
                TextField(controller: scheduled, decoration: const InputDecoration(labelText: 'Scheduled time (ISO 8601)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: selectedArea == null ? null : () => Navigator.pop(context, [
                selectedArea.toString(), description.text.trim(), address.text.trim(),
                latitude.text.trim(), longitude.text.trim(), scheduled.text.trim(),
              ]),
              child: const Text('Publish'),
            ),
          ],
        ),
      ),
    );

    description.dispose();
    address.dispose();
    latitude.dispose();
    longitude.dispose();
    scheduled.dispose();
    if (values == null || values.length != 6) return;

    setState(() => _isCreating = true);
    try {
      final token = await _tokenStorage.getAccessToken();
      if (token == null || token.isEmpty) throw Exception('Please log in again.');
      await _apiService.createScheduledOutage(
        token: token,
        areaId: int.parse(values[0]),
        description: values[1],
        locationAddress: values[2],
        latitude: values[3],
        longitude: values[4],
        scheduledFor: values[5],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scheduled notice published.')));
      await _loadOutages();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadAreas() async {
    final token = await _tokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return [];
    final areas = await _apiService.getAreas(token);
    return areas.whereType<Map>().map((area) => Map<String, dynamic>.from(area)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review outage reports'),
        actions: [
          IconButton(
            onPressed: _isCreating ? null : _createScheduledOutage,
            icon: const Icon(Icons.event_note_outlined),
            tooltip: 'Create scheduled notice',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadOutages,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _MessageState(message: _error!, onRetry: _loadOutages);
    }
    if (_outages.isEmpty) {
      return const _MessageState(message: 'No outage reports found.');
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _outages.length,
      separatorBuilder: (_, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final outage = _outages[index];
        final status = outage['status']?.toString() ?? 'unknown';
        final isRejected = status == 'rejected';
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            title: Text(outage['area_name']?.toString() ?? 'Unknown area'),
            subtitle: Text(
              '${outage['description'] ?? 'No description'}\nStatus: $status',
            ),
            isThreeLine: true,
            trailing: isRejected
                ? const Icon(Icons.block, color: Colors.black45)
                : Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        onPressed: () => _respondToOutage(outage),
                        icon: const Icon(Icons.reply_outlined),
                        tooltip: 'Respond to reporter',
                      ),
                      IconButton(
                        onPressed: () => _rejectOutage(outage),
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Reject report',
                      ),
                    ],
                  ),
          ),
        );
      },
    );
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
