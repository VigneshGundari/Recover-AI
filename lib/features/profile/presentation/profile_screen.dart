import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recover_ai/core/theme/app_theme.dart';
import 'package:recover_ai/features/user/data/user_model.dart';
import 'package:recover_ai/features/user/data/user_repository.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _emergencyNameController;
  late TextEditingController _emergencyPhoneController;
  
  // Doctor-specific controllers
  late TextEditingController _degreeController;
  late TextEditingController _clinicAddressController;
  late TextEditingController _altPhoneController;

  DateTime? _selectedDOB;
  String? _selectedGender;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProfileProvider).value;
    _nameController = TextEditingController(text: user?.name);
    _phoneController = TextEditingController(text: user?.phone);
    _addressController = TextEditingController(text: user?.address);
    _emergencyNameController = TextEditingController(text: user?.emergencyContactName);
    _emergencyPhoneController = TextEditingController(text: user?.emergencyContactPhone);
    _degreeController = TextEditingController(text: user?.medicalDegree);
    _clinicAddressController = TextEditingController(text: user?.clinicAddress);
    _altPhoneController = TextEditingController(text: user?.alternativePhone);
    _selectedDOB = user?.dateOfBirth;
    _selectedGender = user?.gender;

    // If profile is incomplete, start in edit mode
    final isIncomplete = user?.phone == null || 
        (user?.role == UserRole.doctor && user?.medicalDegree == null) ||
        (user?.role == UserRole.caretaker && user?.gender == null);

    if (isIncomplete) {
      _isEditing = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _degreeController.dispose();
    _clinicAddressController.dispose();
    _altPhoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final repository = ref.read(userRepositoryProvider);
    final user = ref.read(currentUserProfileProvider).value;

    if (user == null) return;

    final updatedData = {
      'name': _nameController.text,
      'phone': _phoneController.text,
      'address': _addressController.text,
      'onboardingCompleted': true,
      if (user.role == UserRole.patient || user.role == UserRole.caretaker) ...{
        'gender': _selectedGender,
        'date_of_birth': _selectedDOB,
      },
      if (user.role == UserRole.patient) ...{
        'emergency_contact_name': _emergencyNameController.text,
        'emergency_contact_phone': _emergencyPhoneController.text,
      },
      if (user.role == UserRole.doctor) ...{
        'medical_degree': _degreeController.text,
        'clinic_address': _clinicAddressController.text,
        'alternative_phone': _altPhoneController.text,
      },
      if (user.role == UserRole.caretaker) ...{
        'alternative_phone': _altPhoneController.text,
      }
    };

    try {
      await repository.updateUser(user.uid, updatedData);
      setState(() => _isEditing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: AppTheme.primaryColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.dangerColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProfileProvider).value;
    final isDoctor = user?.role == UserRole.doctor;
    final isCaretaker = user?.role == UserRole.caretaker;

    return Scaffold(
      appBar: AppBar(
        title: Text(isDoctor ? 'Professional Clinical Profile' : isCaretaker ? 'Caregiver Profile' : 'Your Medical Profile'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.visibility_rounded : Icons.edit_rounded, color: AppTheme.primaryColor),
            onPressed: () => setState(() => _isEditing = !_isEditing),
            tooltip: _isEditing ? 'View Mode' : 'Edit Mode',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isEditing ? _buildEditMode(user) : _buildViewMode(user),
        ),
      ),
    );
  }

  Widget _buildViewMode(UserModel? user) {
    final isDoctor = user?.role == UserRole.doctor;
    final isCaretaker = user?.role == UserRole.caretaker;

    return Column(
      key: const ValueKey('view_mode'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Basic Information'),
        const SizedBox(height: 16),
        _buildInfoCard('Full Name', _nameController.text, Icons.person_rounded),
        
        if (!isDoctor) ...[
          const SizedBox(height: 12),
          _buildInfoCard('Gender', _selectedGender ?? 'Not set', Icons.wc_rounded),
          const SizedBox(height: 12),
          _buildInfoCard('Date of Birth', _selectedDOB == null ? 'Not set' : DateFormat('dd MMM yyyy').format(_selectedDOB!), Icons.cake_rounded),
        ],
        
        const SizedBox(height: 32),
        if (isDoctor) ...[
          _buildSectionTitle('Clinical Professional Profile'),
          const SizedBox(height: 16),
          _buildInfoCard('Medical Degree', _degreeController.text, Icons.school_rounded),
          const SizedBox(height: 12),
          _buildInfoCard('Clinic / Hospital Address', _clinicAddressController.text, Icons.business_rounded),
          const SizedBox(height: 12),
          _buildInfoCard('Alternative Contact', _altPhoneController.text, Icons.contact_phone_rounded),
          const SizedBox(height: 32),
        ],

        _buildSectionTitle('Contact Details'),
        const SizedBox(height: 16),
        _buildInfoCard('Mobile Number', _phoneController.text, Icons.phone_rounded),
        if (isCaretaker) ...[
          const SizedBox(height: 12),
          _buildInfoCard('Alternative Contact', _altPhoneController.text, Icons.contact_phone_outlined),
        ],
        if (!isDoctor) ...[
          const SizedBox(height: 12),
          _buildInfoCard('Primary Address', _addressController.text, Icons.home_rounded),
        ],
        
        if (user?.role == UserRole.patient) ...[
          const SizedBox(height: 32),
          _buildSectionTitle('Emergency Contact (Guardian/Peer)'),
          const SizedBox(height: 16),
          _buildInfoCard('Contact Name', _emergencyNameController.text, Icons.badge_rounded),
          const SizedBox(height: 12),
          _buildInfoCard('Contact Phone', _emergencyPhoneController.text, Icons.contact_phone_rounded),
          const SizedBox(height: 32),
        ],

        if (isDoctor && user?.practiceCode != null) ...[
          _buildSectionTitle('Practice Connectivity'),
          const SizedBox(height: 16),
          _buildInfoCard('Practice Code (Share with Patients)', user!.practiceCode!, Icons.vpn_key_rounded),
          const SizedBox(height: 32),
        ],
      ],
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(value.isEmpty ? 'Not set' : value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditMode(UserModel? user) {
    final isDoctor = user?.role == UserRole.doctor;
    final isCaretaker = user?.role == UserRole.caretaker;

    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('edit_mode'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Basic Information'),
          const SizedBox(height: 16),
          _buildTextField('Full Name', _nameController, Icons.person_rounded),
          
          if (!isDoctor) ...[
            const SizedBox(height: 12),
            _buildGenderPicker(),
            const SizedBox(height: 12),
            _buildDatePicker(context),
          ],
          
          const SizedBox(height: 32),
          if (isDoctor) ...[
            _buildSectionTitle('Clinical Professional Profile'),
            const SizedBox(height: 16),
            _buildTextField('Medical Degree (MD, MBBS, etc.)', _degreeController, Icons.school_rounded),
            const SizedBox(height: 12),
            _buildTextField('Clinic / Hospital Address', _clinicAddressController, Icons.business_rounded, maxLines: 3),
            const SizedBox(height: 12),
            _buildTextField('Alternative Contact', _altPhoneController, Icons.contact_phone_rounded, keyboardType: TextInputType.phone),
            const SizedBox(height: 32),
          ],

          _buildSectionTitle('Contact Details'),
          const SizedBox(height: 16),
          _buildTextField('Mobile Number', _phoneController, Icons.phone_rounded, keyboardType: TextInputType.phone),
          
          if (isCaretaker) ...[
            const SizedBox(height: 12),
            _buildTextField('Alternative Contact', _altPhoneController, Icons.contact_phone_outlined, keyboardType: TextInputType.phone),
          ],

          if (!isDoctor) ...[
            const SizedBox(height: 12),
            _buildTextField('Primary Address', _addressController, Icons.home_rounded, maxLines: 3),
            
            if (user?.role == UserRole.patient) ...[
              const SizedBox(height: 32),
              _buildSectionTitle('Emergency Contact (Guardian/Peer)'),
              const SizedBox(height: 16),
              _buildTextField('Contact Name', _emergencyNameController, Icons.badge_rounded),
              const SizedBox(height: 12),
              _buildTextField('Contact Phone', _emergencyPhoneController, Icons.contact_phone_rounded, keyboardType: TextInputType.phone),
            ],
          ],
          
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveProfile,
              child: Text(isDoctor ? 'Save Professional Profile' : 'Save Profile'),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.1),
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
        prefixIcon: Icon(icon, color: AppTheme.textSecondary),
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
        prefixIcon: Icon(Icons.wc_rounded, color: AppTheme.textSecondary),
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
          prefixIcon: Icon(Icons.cake_rounded, color: AppTheme.textSecondary),
        ),
        child: Text(
          _selectedDOB == null ? 'Select Date' : DateFormat('dd MMM yyyy').format(_selectedDOB!),
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
