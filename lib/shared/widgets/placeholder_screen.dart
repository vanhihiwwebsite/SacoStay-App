import 'package:flutter/material.dart';

import 'app_ui.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      title: title,
      subtitle: subtitle,
      icon: Icons.construction_outlined,
    );
  }
}
