import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:recover_ai/core/theme/app_theme.dart';
import 'package:recover_ai/features/user/data/user_model.dart';
import '../../user/data/user_repository.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameController = TextEditingController();
  UserRole _selectedRole = UserRole.patient;
  bool _isLoading = false;

  void _finishOnboarding() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Please enter your name');
      return;
    }
    
    setState(() => _isLoading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    
    try {
      if (uid != null) {
        final data = {
          'name': name,
          'role': _selectedRole.name,
          'onboardingCompleted': true,
        };

        await ref.read(userRepositoryProvider).updateUser(uid, data);
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to save: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.dangerColor));
  }

  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome to RECOVER AI',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tell us a bit about yourself to personalize your experience.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 48),

              _buildSectionTitle('ACCOUNT BASICS'),
              const SizedBox(height: 12),
              _buildInput('Full Name', _nameController, Icons.person_outline_rounded),
              const SizedBox(height: 32),

              _buildSectionTitle('YOUR ROLE'),
              const SizedBox(height: 12),
              _RoleSelector(role: UserRole.patient, current: _selectedRole, onSelect: (r) => setState(() => _selectedRole = r), title: 'Patient', icon: Icons.health_and_safety_rounded, desc: 'I am recovering from surgical treatment.'),
              const SizedBox(height: 16),
              _RoleSelector(role: UserRole.caretaker, current: _selectedRole, onSelect: (r) => setState(() => _selectedRole = r), title: 'Caretaker', icon: Icons.people_rounded, desc: 'I am helping a loved one stay on track.'),
              const SizedBox(height: 16),
              _RoleSelector(role: UserRole.doctor, current: _selectedRole, onSelect: (r) => setState(() => _selectedRole = r), title: 'Doctor (HCP)', icon: Icons.medical_services_rounded, desc: 'I am a healthcare professional monitoring patients.'),
              
              const SizedBox(height: 48),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _finishOnboarding,
                    style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), backgroundColor: AppTheme.primaryColor),
                    child: const Text('Complete Setup', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
     return Text(title, style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 13));
  }

  Widget _buildInput(String hint, TextEditingController controller, IconData icon, {TextInputType? keyboardType}) {
     return TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24),
          filled: true,
          fillColor: AppTheme.surfaceColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          prefixIcon: Icon(icon, color: AppTheme.primaryColor),
        ),
      );
  }
}

class _RoleSelector extends StatelessWidget {
  final UserRole role;
  final UserRole current;
  final Function(UserRole) onSelect;
  final String title;
  final String desc;
  final IconData icon;

  const _RoleSelector({
    required this.role,
    required this.current,
    required this.onSelect,
    required this.title,
    required this.desc,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = role == current;
    return GestureDetector(
      onTap: () => onSelect(role),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.15) : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.white10, width: 2),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(desc, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }
}
