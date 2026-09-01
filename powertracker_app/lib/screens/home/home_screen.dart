import 'package:flutter/material.dart';

import '../dashboard/dashboard_screen.dart';

class HomeScreen extends StatelessWidget {
  final String email;

  const HomeScreen({
    super.key,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardScreen(email: email);
  }
}
