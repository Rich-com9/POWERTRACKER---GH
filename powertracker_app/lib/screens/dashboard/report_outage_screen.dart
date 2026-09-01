import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../core/storage/token_storage.dart';
import '../../services/api_service.dart';
import '../../services/offline_report_storage.dart';

class ReportOutageScreen extends StatefulWidget {
  const ReportOutageScreen({super.key});

  @override
  State<ReportOutageScreen> createState() => _ReportOutageScreenState();
}

class _ReportOutageScreenState extends State<ReportOutageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _apiService = ApiService();
  final _tokenStorage = TokenStorage();
  final _offlineStorage = OfflineReportStorage();
  final _geocoding = Geocoding();

  List<dynamic> _areas = [];
  int? _selectedAreaId;
  String _outageType = 'unplanned';
  String _outageTiming = 'now';
  XFile? _selectedImage;
  bool _isLoadingAreas = true;
  bool _isSubmitting = false;
  bool _isLocating = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadAreas();
  }

  Future<void> _loadAreas() async {
    try {
      final token = await _tokenStorage.getAccessToken();

      if (token == null || token.isEmpty) {
        throw Exception('Please log in again to report an outage.');
      }

      final areas = await _apiService.getAreas(token);

      if (!mounted) return;

      setState(() {
        _areas = areas;
        _isLoadingAreas = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoadingAreas = false;
        _loadError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate() || _selectedAreaId == null) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final token = await _tokenStorage.getAccessToken();

      if (token == null || token.isEmpty) {
        throw Exception('Please log in again to report an outage.');
      }

      await _apiService.createOutage(
        token: token,
        areaId: _selectedAreaId!,
        description: _descriptionController.text.trim(),
        locationAddress: _locationController.text.trim(),
        latitude: _latitudeController.text.trim(),
        longitude: _longitudeController.text.trim(),
        outageType: _outageType,
        outageTime: _outageTiming,
        imagePath: _selectedImage?.path,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Outage reported successfully.')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      await _offlineStorage.saveReport({
        'area': _selectedAreaId,
        'description': _descriptionController.text.trim(),
        'location_address': _locationController.text.trim(),
        'latitude': _latitudeController.text.trim(),
        'longitude': _longitudeController.text.trim(),
        'outage_type': _outageType,
        'outage_time': _outageTiming,
        'image_path': _selectedImage?.path,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not connect. Report saved and will sync later.'),
        ),
      );
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Please enable location services first.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission was not granted.');
      }

      final position = await Geolocator.getCurrentPosition();
      final address = await _gpsAddress(
        position.latitude,
        position.longitude,
      );

      _latitudeController.text = position.latitude.toStringAsFixed(6);
      _longitudeController.text = position.longitude.toStringAsFixed(6);
      _locationController.text = address;
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<String> _gpsAddress(double latitude, double longitude) async {
    try {
      final response = await http.get(
        Uri.https(
          'nominatim.openstreetmap.org',
          '/reverse',
          {
            'lat': latitude.toString(),
            'lon': longitude.toString(),
            'format': 'jsonv2',
            'addressdetails': '1',
            'zoom': '18',
          },
        ),
        headers: const {
          'User-Agent': 'PowerTrackerGH/1.0 (GPS address lookup)',
        },
      );
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result is Map) {
          final address = result['address'];
          if (address is Map) {
            final formatted = _formatGpsAddress(
              Map<String, dynamic>.from(address),
            );
            if (formatted.isNotEmpty) return formatted;
          }
          final displayName = result['display_name']?.toString().trim();
          if (displayName != null && displayName.isNotEmpty) {
            return displayName;
          }
        }
      }
    } catch (_) {}

    final placemarks = await _geocoding.placemarkFromCoordinates(
      latitude,
      longitude,
    );
    final place = placemarks.isEmpty ? null : placemarks.first;
    return _addressFrom(place);
  }

  String _formatGpsAddress(Map<String, dynamic> address) {
    final parts = <String>[];
    void add(String? value) {
      final normalized = value?.trim();
      if (normalized != null && normalized.isNotEmpty && !parts.contains(normalized)) {
        parts.add(normalized);
      }
    }

    add(address['house_number']?.toString());
    add(address['road']?.toString());
    add(address['neighbourhood']?.toString() ?? address['suburb']?.toString());
    add(
      address['village']?.toString() ??
          address['town']?.toString() ??
          address['city']?.toString() ??
          address['municipality']?.toString(),
    );
    add(
      address['district']?.toString() ??
          address['county']?.toString() ??
          address['state_district']?.toString(),
    );
    add(address['state']?.toString());
    add(address['country']?.toString());
    return parts.join(', ');
  }

  String _addressFrom(Placemark? place, {String fallback = 'Current location'}) {
    if (place == null) return fallback;
    return [place.street, place.locality, place.administrativeArea]
        .where((part) => part != null && part.trim().isNotEmpty)
        .join(', ');
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null && mounted) setState(() => _selectedImage = image);
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  String? _coordinate(String? value, String label) {
    final requiredError = _required(value, label);
    if (requiredError != null) return requiredError;

    if (double.tryParse(value!.trim()) == null) {
      return 'Enter a valid $label';
    }
    return null;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report outage')),
      body: _isLoadingAreas
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _ErrorState(message: _loadError!, onRetry: _loadAreas)
              : _buildForm(),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Help your community stay informed.',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<int>(
              initialValue: _selectedAreaId,
              decoration: const InputDecoration(
                labelText: 'Affected area',
                border: OutlineInputBorder(),
              ),
              items: _areas.map((area) {
                final areaMap = Map<String, dynamic>.from(area as Map);
                final id = areaMap['id'] as int;
                return DropdownMenuItem<int>(
                  value: id,
                  child: Text(
                    '${areaMap['name']} - ${areaMap['region'] ?? 'Unknown region'}',
                  ),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedAreaId = value),
              validator: (value) => value == null ? 'Area is required' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _outageType,
              decoration: const InputDecoration(
                labelText: 'Outage type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'unplanned', child: Text('Unplanned')),
                DropdownMenuItem(value: 'planned', child: Text('Planned')),
                DropdownMenuItem(value: 'unknown', child: Text('Unknown')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _outageType = value);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _outageTiming,
              decoration: const InputDecoration(
                labelText: 'When did the power go out?',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'now', child: Text('It just went out')),
                DropdownMenuItem(value: 'earlier_today', child: Text('Earlier today')),
                DropdownMenuItem(value: 'yesterday', child: Text('Yesterday')),
                DropdownMenuItem(value: 'unknown', child: Text('I am not sure')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _outageTiming = value);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Current location',
                hintText: 'Use your GPS location',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.location_on_outlined),
                suffixIcon: _isLocating
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        tooltip: 'Get current GPS address',
                        onPressed: _useCurrentLocation,
                        icon: const Icon(Icons.my_location),
                      ),
              ),
              validator: (value) => _required(value, 'Location'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Describe what is happening',
                border: OutlineInputBorder(),
              ),
              validator: (value) => _required(value, 'Description'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latitudeController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => _coordinate(value, 'latitude'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _longitudeController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => _coordinate(value, 'longitude'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                _selectedImage == null ? 'Attach an image (optional)' : 'Change attached image',
              ),
            ),
            if (_selectedImage != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(_selectedImage!.path),
                  height: 160,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => ListTile(
                    leading: const Icon(Icons.image_outlined),
                    title: Text(_selectedImage!.name),
                    trailing: IconButton(
                      onPressed: () => setState(() => _selectedImage = null),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                child: _isSubmitting
                    ? const CircularProgressIndicator()
                    : const Text('Submit report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

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
