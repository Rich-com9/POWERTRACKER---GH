import 'package:flutter/material.dart';

import '../../core/storage/token_storage.dart';
import '../../services/api_service.dart';
import '../../services/offline_report_storage.dart';
import '../analytics/analytics_screen.dart';
import '../areas/areas_screen.dart';
import '../map/map_screen.dart';
import '../notifications/notifications_screen.dart';
import '../outages/outages_screen.dart';
import '../profile/profile_screen.dart';
import '../areas/saved_areas_screen.dart';
import '../updates/latest_updates_screen.dart';
import 'report_outage_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String email;

  const DashboardScreen({
    super.key,
    required this.email,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int selectedIndex = 0;

  final ApiService _apiService = ApiService();
  final TokenStorage _tokenStorage = TokenStorage();
  final OfflineReportStorage _offlineStorage = OfflineReportStorage();

  bool _isLoadingOutages = true;
  String? _outageError;
  Map<String, dynamic>? _latestOutage;
  int _activeOutageCount = 0;
  int _unreadNotificationCount = 0;
  String? _fullName;

  @override
  void initState() {
    super.initState();
    _loadProfileName();
    _loadActiveOutage();
    _loadUnreadNotifications();
  }

  Future<void> _loadUnreadNotifications() async {
    final token = await _tokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return;

    try {
      final notifications = await _apiService.getNotifications(token);
      if (!mounted) return;
      setState(() {
        _unreadNotificationCount = notifications
            .whereType<Map>()
            .where((notification) => notification['is_read'] != true)
            .length;
      });
    } catch (_) {
      // The dashboard remains usable if notification loading fails.
    }
  }

  Future<void> _loadProfileName() async {
    final token = await _tokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return;

    try {
      final profile = await _apiService.getProfile(token);
      final name = profile['name']?.toString().trim();
      if (!mounted || name == null || name.isEmpty) return;
      setState(() => _fullName = name);
    } catch (_) {
      // Keep the email fallback when the profile cannot be loaded.
    }
  }

  // ======================================================
  // LOAD ACTIVE OUTAGES
  // ======================================================

  Future<void> _loadActiveOutage() async {
    setState(() {
      _isLoadingOutages = true;
      _outageError = null;
    });

    try {
      final token = await _tokenStorage.getAccessToken();

      if (token == null || token.isEmpty) {
        if (!mounted) return;

        setState(() {
          _isLoadingOutages = false;
          _outageError = 'Please log in again to view outages.';
        });

        return;
      }

      await _syncPendingReports(token);
      final outages = await _apiService.getActiveOutages(token);

      if (!mounted) return;

      if (outages.isEmpty) {
        setState(() {
          _isLoadingOutages = false;
          _activeOutageCount = 0;
          _latestOutage = null;
          _outageError = null;
        });

        return;
      }

      final firstOutage = outages.first;

      if (firstOutage is Map<String, dynamic>) {
        setState(() {
          _activeOutageCount = outages.length;
          _latestOutage = firstOutage;
          _isLoadingOutages = false;
          _outageError = null;
        });

        return;
      }

      if (firstOutage is Map) {
        setState(() {
          _activeOutageCount = outages.length;
          _latestOutage = Map<String, dynamic>.from(firstOutage);
          _isLoadingOutages = false;
          _outageError = null;
        });

        return;
      }

      setState(() {
        _isLoadingOutages = false;
        _activeOutageCount = 0;
        _latestOutage = null;
        _outageError = 'No usable outage data was returned.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingOutages = false;
        _activeOutageCount = 0;
        _outageError = e.toString().replaceFirst(
              'Exception: ',
              '',
            );
      });
    }
  }

  Future<void> _syncPendingReports(String token) async {
    final pendingReports = await _offlineStorage.getPendingReports();
    if (pendingReports.isEmpty) return;

    final failedReports = <Map<String, dynamic>>[];

    for (final report in pendingReports) {
      try {
        await _apiService.createOutage(
          token: token,
          areaId: int.parse(report['area'].toString()),
          description: report['description']?.toString() ?? '',
          locationAddress: report['location_address']?.toString() ?? '',
          latitude: report['latitude']?.toString() ?? '',
          longitude: report['longitude']?.toString() ?? '',
          outageType: report['outage_type']?.toString() ?? 'unknown',
          outageTime: report['outage_time']?.toString() ?? 'unknown',
          imagePath: report['image_path']?.toString(),
        );
      } catch (_) {
        failedReports.add(report);
      }
    }

    await _offlineStorage.replaceReports(failedReports);
  }

  // ======================================================
  // OPEN REPORT OUTAGE SCREEN
  // ======================================================

  Future<void> _openReportOutage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ReportOutageScreen(),
      ),
    );

    // If an outage was successfully reported,
    // refresh the dashboard.
    if (result == true) {
      await _loadActiveOutage();
    }
  }

  Future<void> _openOutages() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const OutagesScreen(),
      ),
    );
  }

  Future<void> _openAreas() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AreasScreen(),
      ),
    );
  }

  Future<void> _openMap() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MapScreen(),
      ),
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationsScreen(),
      ),
    );
    await _loadUnreadNotifications();
  }

  Future<void> _openLatestUpdates() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LatestUpdatesScreen(),
      ),
    );
  }

  Future<void> _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfileScreen(),
      ),
    );
  }

  Future<void> _openSavedAreas() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SavedAreasScreen(),
      ),
    );
  }

  Future<void> _openAnalytics() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AnalyticsScreen(),
      ),
    );
  }

  // ======================================================
  // BUILD
  // ======================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FF),

      // ==================================================
      // TOP HEADER
      // ==================================================

      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(82),
        child: Container(
          color: const Color(0xFF3F51B5),
          padding: const EdgeInsets.only(
            left: 18,
            right: 14,
            top: 12,
            bottom: 10,
          ),
          child: SafeArea(
            child: Row(
              children: [
                // Logo
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.asset(
                      'assets/images/powertracker_gh_logo.png',
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                // Title
                const Expanded(
                  child: Text(
                    'Home',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Notifications
                IconButton(
                  onPressed: _openNotifications,
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(
                        Icons.notifications_none,
                        color: Colors.white,
                        size: 31,
                      ),
                      if (_unreadNotificationCount > 0)
                        Positioned(
                          right: -7,
                          top: -7,
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF3F51B5), width: 2),
                            ),
                            child: Text(
                              _unreadNotificationCount > 99
                                  ? '99+'
                                  : '$_unreadNotificationCount',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 4),

                // Get Help
                Container(
                  height: 54,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: TextButton.icon(
                    onPressed: () {
                      _showHelpDialog(context);
                    },
                    icon: const Icon(
                      Icons.help_outline,
                      color: Color(0xFF303F9F),
                      size: 25,
                    ),
                    label: const Text(
                      'Get Help',
                      style: TextStyle(
                        color: Color(0xFF303F9F),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // ==================================================
      // BODY
      // ==================================================

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadActiveOutage,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 30),
            child: Column(
              children: [
                // ==========================================
                // ANNOUNCEMENT
                // ==========================================

                Container(
                  margin: const EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    22,
                  ),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8EAF6),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.campaign_outlined,
                          color: Color(0xFF3F51B5),
                          size: 28,
                        ),
                      ),

                      const SizedBox(width: 14),

                      Expanded(
                        child: _isLoadingOutages
                            ? const Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PowerTracker GH',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF555555),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Loading live outage information...',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            : _errorOrOutageMessage(),
                      ),

                      IconButton(
                        onPressed: _openOutages,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        tooltip: 'View all outages',
                        icon: const Icon(
                          Icons.arrow_forward_ios,
                          size: 20,
                          color: Color(0xFF3F51B5),
                        ),
                      ),
                    ],
                  ),
                ),

                // ==========================================
                // WELCOME
                // ==========================================

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Welcome, ${_fullName ?? widget.email}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ==========================================
                // FEATURE GRID
                // ==========================================

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth =
                          (constraints.maxWidth - 16) / 2;

                      return Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          SizedBox(
                            width: cardWidth,
                            height: 184,
                            child: DashboardCard(
                              title: 'Report Outage',
                              subtitle: 'Report a power outage',
                              icon: Icons.power_off_outlined,
                              iconColor: const Color(0xFFE53935),
                              backgroundColor:
                                  const Color(0xFFFFF1F1),
                              onTap: _openReportOutage,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            height: 184,
                            child: DashboardCard(
                              title: 'Outages',
                              subtitle: _isLoadingOutages
                                  ? 'Loading active outages'
                                  : '$_activeOutageCount active ${_activeOutageCount == 1 ? 'outage' : 'outages'}',
                              icon: Icons.warning_amber_rounded,
                              iconColor: const Color(0xFF1976D2),
                              backgroundColor:
                                  const Color(0xFFEAF5FF),
                              onTap: _openOutages,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            height: 184,
                            child: DashboardCard(
                              title: 'Areas',
                              subtitle: 'Check your area',
                              icon: Icons.map_outlined,
                              iconColor: const Color(0xFF43A047),
                              backgroundColor:
                                  const Color(0xFFF0FFF3),
                              onTap: _openAreas,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            height: 184,
                            child: DashboardCard(
                              title: 'Notifications',
                                subtitle: _unreadNotificationCount == 0
                                  ? 'No new notifications'
                                  : '$_unreadNotificationCount new notification${_unreadNotificationCount == 1 ? '' : 's'}',
                              icon: Icons.notifications_active_outlined,
                              iconColor: const Color(0xFF7B1FA2),
                              backgroundColor:
                                  const Color(0xFFF8F0FF),
                              onTap: _openNotifications,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            height: 184,
                            child: DashboardCard(
                              title: 'Latest Updates',
                              subtitle: 'View community updates',
                              icon: Icons.campaign_outlined,
                              iconColor: const Color(0xFF3F51B5),
                              backgroundColor:
                                  const Color(0xFFEFF1FF),
                              onTap: _openLatestUpdates,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            height: 184,
                            child: DashboardCard(
                              title: 'My Profile',
                              subtitle: 'Manage your account',
                              icon: Icons.person_outline,
                              iconColor: const Color(0xFF00897B),
                              backgroundColor:
                                  const Color(0xFFEFFFFC),
                              onTap: _openProfile,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            height: 184,
                            child: DashboardCard(
                              title: 'Saved Areas',
                              subtitle: 'Your favourite areas',
                              icon: Icons.bookmark_border,
                              iconColor: const Color(0xFFFF8F00),
                              backgroundColor:
                                  const Color(0xFFFFF8E8),
                              onTap: _openSavedAreas,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            height: 184,
                            child: DashboardCard(
                              title: 'Analytics',
                              subtitle: 'View outage statistics',
                              icon: Icons.insights_outlined,
                              iconColor: const Color(0xFF5E35B1),
                              backgroundColor:
                                  const Color(0xFFF2EEFF),
                              onTap: _openAnalytics,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // ==================================================
      // BOTTOM NAVIGATION
      // ==================================================

      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        backgroundColor: Colors.white,
        elevation: 8,

        onDestinationSelected: (index) async {
          if (index == 1) {
            await _openOutages();
            if (!mounted) return;
            setState(() => selectedIndex = 0);
            return;
          }

          if (index == 2) {
            await _openMap();
            if (!mounted) return;
            setState(() => selectedIndex = 0);
            return;
          }

          if (index == 3) {
            await _openNotifications();
            if (!mounted) return;
            setState(() => selectedIndex = 0);
            return;
          }

          if (index == 4) {
            await _openProfile();
            if (!mounted) return;
            setState(() => selectedIndex = 0);
            return;
          }

          setState(() {
            selectedIndex = index;
          });
        },

        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.warning_amber_outlined),
            selectedIcon: Icon(Icons.warning_amber),
            label: 'Outages',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // ======================================================
  // HELP DIALOG
  // ======================================================

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.help_outline,
                color: Color(0xFF3F51B5),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'How PowerTracker works',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _HelpItem(
                  icon: Icons.power_off_outlined,
                  title: 'Report an outage',
                  description:
                      'Add the affected area, choose when the power went out, '
                      'and use GPS or address search to share the location.',
                ),
                _HelpItem(
                  icon: Icons.warning_amber_rounded,
                  title: 'Check outages',
                  description:
                      'Open Outages to view active and restored reports. '
                      'You can confirm an active outage once you have experienced it.',
                ),
                _HelpItem(
                  icon: Icons.map_outlined,
                  title: 'Use the map',
                  description:
                      'Open Map to see active reports that include valid GPS coordinates. '
                      'Tap a marker for more information.',
                ),
                _HelpItem(
                  icon: Icons.notifications_none,
                  title: 'Stay updated',
                  description:
                      'Notifications contain outage and restoration updates for your account.',
                ),
                _HelpItem(
                  icon: Icons.location_on_outlined,
                  title: 'Location access',
                  description:
                      'Allow location permission when prompted to use your current GPS location. '
                      'You can search for an address instead.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  // ======================================================
  // ANNOUNCEMENT CONTENT
  // ======================================================

  Widget _errorOrOutageMessage() {
    // Error
    if (_outageError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PowerTracker GH',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF555555),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _outageError!,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    // No active outages
    final outage = _latestOutage;

    if (outage == null) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PowerTracker GH',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF555555),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'No active outages',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'There are no reported outages at the moment.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
              height: 1.4,
            ),
          ),
        ],
      );
    }

    // Active outage
    final areaName =
        outage['area_name'] ?? 'Unknown area';

    final description =
        outage['description'] ??
            'No outage details reported.';

    final outageType =
        outage['outage_type'] ?? 'unknown';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Active outage',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF555555),
          ),
        ),

        const SizedBox(height: 8),

        Text(
          '${areaName.toString().trim()} • '
          '${outageType.toString().trim()} outage',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          description.toString(),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _HelpItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _HelpItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF3F51B5), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.black54,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================
// DASHBOARD CARD
// ======================================================

class DashboardCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final VoidCallback onTap;

  const DashboardCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: iconColor.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(18),
                ),
                child: Icon(
                  icon,
                  size: 36,
                  color: iconColor,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}