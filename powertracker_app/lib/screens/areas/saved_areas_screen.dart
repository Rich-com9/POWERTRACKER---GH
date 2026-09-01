import 'package:flutter/material.dart';

import '../../core/storage/token_storage.dart';
import '../../services/api_service.dart';

class SavedAreasScreen extends StatefulWidget {
  const SavedAreasScreen({super.key});

  @override
  State<SavedAreasScreen> createState() => _SavedAreasScreenState();
}

class _SavedAreasScreenState extends State<SavedAreasScreen> {
  final _apiService = ApiService();
  final _tokenStorage = TokenStorage();

  List<Map<String, dynamic>> _savedAreas = [];
  List<Map<String, dynamic>> _availableAreas = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedAreas();
  }

  Future<String> _token() async {
    final token = await _tokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Please log in again to manage saved areas.');
    }
    return token;
  }

  Future<void> _loadSavedAreas() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _token();
      final savedAreas = await _apiService.getSavedAreas(token);
      final availableAreas = await _apiService.getAreas(token);
      if (!mounted) return;

      setState(() {
        _savedAreas = _mapsFrom(savedAreas);
        _availableAreas = _mapsFrom(availableAreas);
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

  List<Map<String, dynamic>> _mapsFrom(List<dynamic> items) {
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> _showAddAreaDialog() async {
    final savedIds = _savedAreas
        .map((area) => int.tryParse(area['area']?.toString() ?? ''))
        .whereType<int>()
        .toSet();
    final choices = _availableAreas
        .where((area) => !savedIds.contains(int.tryParse(area['id']?.toString() ?? '')))
        .toList();

    if (choices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All available areas are already saved.')),
      );
      return;
    }

    final area = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Save an area'),
        children: choices.map((choice) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, choice),
            child: Text(
              '${choice['name']} - ${choice['region'] ?? 'Unknown region'}',
            ),
          );
        }).toList(),
      ),
    );

    if (area == null) return;
    final areaId = int.tryParse(area['id']?.toString() ?? '');
    if (areaId == null) return;

    setState(() => _isSaving = true);
    try {
      final token = await _token();
      await _apiService.saveArea(token: token, areaId: areaId);
      if (!mounted) return;
      await _loadSavedAreas();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Area saved successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _removeArea(Map<String, dynamic> area) async {
    final savedAreaId = int.tryParse(area['id']?.toString() ?? '');
    if (savedAreaId == null) return;

    try {
      final token = await _token();
      await _apiService.deleteSavedArea(
        token: token,
        savedAreaId: savedAreaId,
      );
      if (!mounted) return;
      await _loadSavedAreas();
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
      appBar: AppBar(
        title: const Text('Saved areas'),
        actions: [
          IconButton(
            onPressed: _isSaving ? null : _showAddAreaDialog,
            icon: const Icon(Icons.add_location_alt_outlined),
            tooltip: 'Save an area',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSavedAreas,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _MessageState(message: _error!, onRetry: _loadSavedAreas);
    }
    if (_savedAreas.isEmpty) {
      return const _MessageState(message: 'You have no saved areas yet.');
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _savedAreas.length,
      separatorBuilder: (_, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final area = _savedAreas[index];
        final count = int.tryParse(area['active_outage_count']?.toString() ?? '') ?? 0;
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.bookmark, color: Color(0xFFFF8F00)),
            title: Text(area['area_name']?.toString() ?? 'Unknown area'),
            subtitle: Text(
              '${area['region'] ?? 'Unknown region'} • $count active ${count == 1 ? 'outage' : 'outages'}',
            ),
            trailing: IconButton(
              onPressed: () => _removeArea(area),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Remove saved area',
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
