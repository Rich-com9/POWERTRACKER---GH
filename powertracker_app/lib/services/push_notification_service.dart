import 'package:firebase_messaging/firebase_messaging.dart';

import '../core/storage/token_storage.dart';
import 'api_service.dart';

class PushNotificationService {
  final _apiService = ApiService();
  final _tokenStorage = TokenStorage();

  Future<void> registerAfterLogin() async {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final deviceToken = await messaging.getToken();
    final accessToken = await _tokenStorage.getAccessToken();

    if (deviceToken == null || accessToken == null) return;

    await _apiService.registerDeviceToken(
      token: accessToken,
      deviceToken: deviceToken,
    );

    messaging.onTokenRefresh.listen((newToken) async {
      final currentAccessToken = await _tokenStorage.getAccessToken();
      if (currentAccessToken == null) return;

      await _apiService.registerDeviceToken(
        token: currentAccessToken,
        deviceToken: newToken,
      );
    });
  }

  void listenForForegroundMessages({
    required void Function(RemoteMessage message) onMessage,
  }) {
    FirebaseMessaging.onMessage.listen(onMessage);
  }
}
