import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recover_ai/core/theme/app_theme.dart';
import 'package:recover_ai/features/user/data/user_model.dart';
import 'package:recover_ai/features/user/data/user_repository.dart';
import 'package:intl/intl.dart';

class CaretakerProfileDialog extends ConsumerStatefulWidget {
  final UserModel user;
  const CaretakerProfileDialog({super.key, required this.user});

  static void show(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CaretakerProfileDialog(user: user),
    );
  }

  @override
  ConsumerState<CaretakerProfileDialog> createState() => _CaretakerProfileDialogState();
}

class _CaretakerProfileDialogState extends ConsumerState<CaretakerProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _altPhoneController;
  late TextEditingController _addressController;
  String? _selectedGender;
  DateTime? _selectedDOB;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _phoneController = TextEditingController(text: widget.user.phone);
    _altPhoneController = TextEditingController(text: widget.user.alternativePhone);
    _addressController = TextEditingController(text: widget.user.address);
    _selectedGender = widget.user.gender;
    _selectedDOB = widget.user.dateOfBirth;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _altPhoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final repository = ref.read(userRepositoryProvider);
      await repository.updateUser(widget.user.uid, {
        'name': _nameController.text,
        'phone': _phoneController.text,
        'alternative_phone': _altPhoneController.text,
        'address': _addressController.text,
        'gender': _selectedGender,
        'date_of_birth': _selectedDOB,
        'onboardingCompleted': true,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.dangerColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Complete Caregiver Profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Ensure patients and doctors can reach you in case of an emergency.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 32),
                
                _buildTextField('Full Name', _nameController, Icons.person_outline_rounded),
                const SizedBox(height: 16),
                
                _buildGenderPicker(),
                const SizedBox(height: 16),
                
                _buildDatePicker(context),
                const SizedBox(height: 16),

                _buildTextField('Primary Phone', _phoneController, Icons.phone_outlined, keyboardType: TextInputType.phone),
                const SizedBox(height: 16),
                
                _buildTextField('Alternative Phone', _altPhoneController, Icons.contact_phone_outlined, keyboardType: TextInputType.phone),
                const SizedBox(height: 16),
                
                _buildTextField('Residential Address', _addressController, Icons.home_outlined, maxLines: 3),
                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : const Text('Save Caregiver Profile'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Center(child: Text('Fill Later', style: TextStyle(color: AppTheme.textSecondary))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {TextInputType? keyboardType, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primaryColor, size: 20),
      ),
      validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
    );
  }

  Widget _buildGenderPicker() {
    return DropdownButtonFormField<String>(
      value: _selectedGender,
      dropdownColor: AppTheme.surfaceColor,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        labelText: 'Gender',
        prefixIcon: Icon(Icons.wc_rounded, color: AppTheme.primaryColor, size: 20),
      ),
      items: ['Male', 'Female', 'Other', 'Prefer not to say']
          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
          .toList(),
      onChanged: (val) => setState(() => _selectedGender = val),
      validator: (value) => value == null ? 'Required' : null,
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _selectedDOB ?? DateTime(1990),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
        );
        if (date != null) setState(() => _selectedDOB = date);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Date of Birth',
          prefixIcon: Icon(Icons.cake_rounded, color: AppTheme.primaryColor, size: 20),
        ),
        child: Text(
          _selectedDOB == null ? 'Select Date' : DateFormat('dd MMM yyyy').format(_selectedDOB!),
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
