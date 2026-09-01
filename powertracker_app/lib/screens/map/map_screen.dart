import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/storage/token_storage.dart';
import '../../services/api_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
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
        throw Exception('Please log in again to view the outage map.');
      }

      final outages = await _apiService.getActiveOutages(token);
      if (!mounted) return;

      setState(() {
        _outages = outages
            .whereType<Map>()
            .map((outage) => Map<String, dynamic>.from(outage))
            .where((outage) => _coordinatesFor(outage) != null)
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

  LatLng? _coordinatesFor(Map<String, dynamic> outage) {
    final latitude = double.tryParse(outage['latitude']?.toString() ?? '');
    final longitude = double.tryParse(outage['longitude']?.toString() ?? '');

    if (latitude == null || longitude == null) return null;
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      return null;
    }

    return LatLng(latitude, longitude);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Outage map')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _MessageState(
                  message: _error!,
                  onRetry: _loadOutages,
                )
              : _buildMap(),
    );
  }

  Widget _buildMap() {
    return Stack(
      children: [
        FlutterMap(
          options: const MapOptions(
            initialCenter: LatLng(5.6037, -0.1870),
            initialZoom: 11,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.powertracker.gh',
            ),
            MarkerLayer(
              markers: _outages.map((outage) {
                final coordinates = _coordinatesFor(outage)!;
                return Marker(
                  point: coordinates,
                  width: 52,
                  height: 52,
                  child: GestureDetector(
                    onTap: () => _showOutageDetails(outage),
                    child: const Icon(
                      Icons.location_on,
                      color: Color(0xFFE53935),
                      size: 46,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Text(
                _outages.isEmpty
                    ? 'No active outages with map coordinates.'
                    : '${_outages.length} active ${_outages.length == 1 ? 'outage' : 'outages'} shown',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showOutageDetails(Map<String, dynamic> outage) {
    final area = outage['area_name']?.toString() ?? 'Unknown area';
    final description = outage['description']?.toString().trim() ?? '';

    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                area,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(description.isEmpty ? 'No description provided.' : description),
              const SizedBox(height: 8),
              Text(
                'Coordinates: ${outage['latitude']}, ${outage['longitude']}',
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
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
    return Center(
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
    );
  }
}
