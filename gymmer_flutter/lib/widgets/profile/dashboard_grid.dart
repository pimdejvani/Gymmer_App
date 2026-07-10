/// A 2-column grid of dashboard buttons on the Profile tab. Dumb list of
/// (icon, label, onTap) entries; later plans append more entries.
library;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../shared_widgets.dart';

class DashboardEntry {
  const DashboardEntry({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class DashboardGrid extends StatelessWidget {
  const DashboardGrid({super.key, required this.entries});

  final List<DashboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.6,
      children: [
        for (final entry in entries)
          GestureDetector(
            onTap: entry.onTap,
            behavior: HitTestBehavior.opaque,
            child: SurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(entry.icon, color: AppColors.textPrimary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
