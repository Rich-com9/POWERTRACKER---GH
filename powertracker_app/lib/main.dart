import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'core/constants/api_constants.dart';
import 'core/storage/token_storage.dart';
import 'services/api_service.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (ApiConstants.baseUrl.isEmpty ||
      (bool.fromEnvironment('dart.vm.product') &&
          !ApiConstants.baseUrl.startsWith('https://'))) {
    throw StateError(
      'Release builds require --dart-define=API_HOST=https://your-api.example.com',
    );
  }

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const PowerTrackerApp());
}

class PowerTrackerApp extends StatelessWidget {
  const PowerTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PowerTracker GH',
      theme: ThemeData(useMaterial3: true),
      home: const SessionGate(),
    );
  }
}

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  final _apiService = ApiService();
  final _tokenStorage = TokenStorage();
  Widget _screen = const Center(child: CircularProgressIndicator());

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final accessToken = await _tokenStorage.getAccessToken();
    final refreshToken = await _tokenStorage.getRefreshToken();

    if (accessToken == null || accessToken.isEmpty) {
      _show(const LoginScreen());
      return;
    }

    try {
      final profile = await _apiService.getProfile(accessToken);
      _show(HomeScreen(email: profile['email']?.toString() ?? ''));
      return;
    } catch (_) {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          final refreshedToken = await _apiService.refreshAccessToken(
            refreshToken,
          );
          if (refreshedToken != null) {
            final profile = await _apiService.getProfile(refreshedToken);
            _show(HomeScreen(email: profile['email']?.toString() ?? ''));
            return;
          }
        } catch (_) {}
      }
    }

    await _tokenStorage.clearTokens();
    _show(const LoginScreen());
  }

  void _show(Widget screen) {
    if (!mounted) return;
    setState(() => _screen = screen);
  }

  @override
  Widget build(BuildContext context) => _screen;
}
