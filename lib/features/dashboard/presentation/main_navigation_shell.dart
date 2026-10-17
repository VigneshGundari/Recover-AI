import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:recover_ai/core/theme/app_theme.dart';

import 'package:recover_ai/features/user/data/user_repository.dart';
import 'package:recover_ai/features/user/data/user_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MainNavigationShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainNavigationShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProfileProvider).value;
    final isPatient = user?.role == UserRole.patient;
    final isCaretaker = user?.role == UserRole.caretaker;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor.withOpacity(0.9),
          border: const Border(top: BorderSide(color: AppTheme.surfaceColor, width: 1)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(context, 0, Icons.dashboard_rounded, 'Dashboard'),
                  _buildNavItem(context, 1, Icons.history_rounded, 'History'),
                  _buildNavItem(context, 2, Icons.health_and_safety_rounded, 'Plan'),
                  _buildNavItem(context, 3, Icons.chat_bubble_rounded, 'Health Guide'),
                  if (isPatient) 
                    _buildNavItem(context, 4, Icons.medical_information_rounded, 'Care Team'),
                  _buildNavItem(context, 5, Icons.person_rounded, 'Profile'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, String label) {
    final isSelected = navigationShell.currentIndex == index;
    final color = isSelected ? AppTheme.primaryColor : AppTheme.textSecondary;

    return GestureDetector(
      onTap: () => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      ),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.fastOutSlowIn,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
