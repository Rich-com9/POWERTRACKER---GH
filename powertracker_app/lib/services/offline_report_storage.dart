import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class OfflineReportStorage {
  static const _reportsKey = 'pending_outage_reports';

  Future<List<Map<String, dynamic>>> getPendingReports() async {
    final preferences = await SharedPreferences.getInstance();
    final encodedReports = preferences.getStringList(_reportsKey) ?? [];

    return encodedReports
        .map((report) => jsonDecode(report))
        .whereType<Map>()
        .map((report) => Map<String, dynamic>.from(report))
        .toList();
  }

  Future<void> saveReport(Map<String, dynamic> report) async {
    final preferences = await SharedPreferences.getInstance();
    final reports = await getPendingReports();
    reports.add(report);

    await preferences.setStringList(
      _reportsKey,
      reports.map(jsonEncode).toList(),
    );
  }

  Future<void> replaceReports(
    List<Map<String, dynamic>> reports,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _reportsKey,
      reports.map(jsonEncode).toList(),
    );
  }
}
