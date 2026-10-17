import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recover_ai/core/theme/app_theme.dart';
import 'package:recover_ai/features/user/data/user_model.dart';
import 'package:recover_ai/features/user/data/user_repository.dart';

class DoctorProfileDialog extends ConsumerStatefulWidget {
  final UserModel doctor;
  const DoctorProfileDialog({super.key, required this.doctor});

  static Future<void> show(BuildContext context, UserModel doctor) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DoctorProfileDialog(doctor: doctor),
    );
  }

  @override
  ConsumerState<DoctorProfileDialog> createState() => _DoctorProfileDialogState();
}

class _DoctorProfileDialogState extends ConsumerState<DoctorProfileDialog> {
  late TextEditingController _degreeController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _degreeController = TextEditingController(text: widget.doctor.medicalDegree);
    _addressController = TextEditingController(text: widget.doctor.clinicAddress);
    _phoneController = TextEditingController(text: widget.doctor.alternativePhone);
  }

  @override
  void dispose() {
    _degreeController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final degree = _degreeController.text.trim();
    final address = _addressController.text.trim();
    final altPhone = _phoneController.text.trim();

    if (degree.isEmpty || address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide your degree and clinic address')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(userRepositoryProvider).updateUser(widget.doctor.uid, {
        'medical_degree': degree,
        'clinic_address': address,
        'alternative_phone': altPhone,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.medical_information_rounded, color: AppTheme.primaryColor, size: 28),
                SizedBox(width: 12),
                Text('Complete Clinical Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Your professional details are visible to patients linked to your practice.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            
            _buildInput('Medical Degree (MD, MBBS, etc.)', _degreeController, Icons.school_outlined),
            const SizedBox(height: 16),
            _buildInput('Clinic / Hospital Address', _addressController, Icons.business_outlined),
            const SizedBox(height: 16),
            _buildInput('Alternative Contact Number', _phoneController, Icons.phone_android_outlined, keyboardType: TextInputType.phone),
            
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: AppTheme.backgroundColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: AppTheme.backgroundColor) 
                  : const Text('Save Professional Profile', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Maybe Later', style: TextStyle(color: Colors.white24)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String hint, TextEditingController controller, IconData icon, {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
        filled: true,
        fillColor: AppTheme.surfaceColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        prefixIcon: Icon(icon, color: AppTheme.primaryColor, size: 20),
      ),
    );
  }
}
