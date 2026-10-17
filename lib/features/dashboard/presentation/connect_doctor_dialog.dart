import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recover_ai/core/theme/app_theme.dart';
import 'package:recover_ai/features/user/data/care_circle_repository.dart';
import 'package:recover_ai/features/user/data/user_repository.dart';

class ConnectDoctorDialog extends ConsumerStatefulWidget {
  const ConnectDoctorDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const ConnectDoctorDialog(),
    );
  }

  @override
  ConsumerState<ConnectDoctorDialog> createState() => _ConnectDoctorDialogState();
}

class _ConnectDoctorDialogState extends ConsumerState<ConnectDoctorDialog> {
  final TextEditingController _codeCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _submit() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = ref.read(currentUserProfileProvider).value;
      if (user == null) throw Exception('User not logged in');

      await ref.read(careCircleRepositoryProvider).joinDoctorPractice(user.uid, code);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully connected to Doctor\'s practice!'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.medical_services_outlined, size: 48, color: AppTheme.primaryColor),
            const SizedBox(height: 16),
            const Text(
              'Connect with Doctor',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter your Doctor\'s 6-character practice code to share your recovery progress.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _codeCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              maxLength: 7, // DR-XXXX
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'DR-XXXX',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.1)),
                counterText: '',
                filled: true,
                fillColor: AppTheme.backgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                errorText: _error,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: AppTheme.backgroundColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: AppTheme.backgroundColor)
                    : const Text('Link Practice', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
            ),
          ],
        ),
      ),
    );
  }
}
