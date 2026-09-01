import 'package:flutter/material.dart';

import '../../core/storage/token_storage.dart';
import '../../services/api_service.dart';
import '../outages/outages_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _apiService = ApiService();
  final _tokenStorage = TokenStorage();

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _error;

  int get _unreadCount => _notifications
      .where((notification) => notification['is_read'] != true)
      .length;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _tokenStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('Please log in again to view notifications.');
      }

      final notifications = await _apiService.getNotifications(token);
      if (!mounted) return;

      setState(() {
        _notifications = notifications
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

  Future<void> _openNotification(Map<String, dynamic> notification) async {
    final notificationId = int.tryParse(notification['id']?.toString() ?? '');
    final isRead = notification['is_read'] == true;

    if (!isRead && notificationId != null) {
      final token = await _tokenStorage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        try {
          await _apiService.markNotificationRead(
            token: token,
            notificationId: notificationId,
          );
          if (!mounted) return;
          setState(() => notification['is_read'] = true);
        } catch (_) {
          // Keep the notification readable even if marking it fails.
        }
      }
    }

    if (!mounted) return;

    final outageId = int.tryParse(notification['outage']?.toString() ?? '');

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification['title']?.toString() ?? 'Notification'),
        content: Text(notification['message']?.toString() ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (outageId != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OutagesScreen(),
                  ),
                );
              },
              child: const Text('View outage'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _unreadCount == 0
              ? 'Notifications'
              : 'Notifications ($_unreadCount)',
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _MessageState(message: _error!, onRetry: _loadNotifications);
    }

    if (_notifications.isEmpty) {
      return const _MessageState(message: 'No notifications yet.');
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _notifications.length,
      separatorBuilder: (_, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        final isRead = notification['is_read'] == true;

        return Card(
          margin: EdgeInsets.zero,
          color: isRead ? null : const Color(0xFFEAF5FF),
          child: ListTile(
            onTap: () => _openNotification(notification),
            leading: Icon(
              _iconFor(notification['notification_type']?.toString()),
              color: isRead ? Colors.black54 : const Color(0xFF1976D2),
            ),
            title: Text(
              notification['title']?.toString() ?? 'Notification',
              style: TextStyle(
                fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
              ),
            ),
            subtitle: Text(
              notification['message']?.toString() ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: isRead
                ? null
                : const Icon(Icons.circle, size: 10, color: Color(0xFF1976D2)),
          ),
        );
      },
    );
  }

  IconData _iconFor(String? type) {
    switch (type) {
      case 'outage':
        return Icons.warning_amber_rounded;
      case 'restored':
        return Icons.power;
      case 'confirmation':
        return Icons.check_circle_outline;
      default:
        return Icons.notifications_none;
    }
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
