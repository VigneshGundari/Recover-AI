import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recover_ai/core/theme/app_theme.dart';
import 'package:recover_ai/features/user/data/user_model.dart';
import 'package:recover_ai/features/user/data/user_repository.dart';
import 'package:recover_ai/features/dashboard/presentation/connect_doctor_dialog.dart';

class CareTeamScreen extends ConsumerWidget {
  const CareTeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctorAsync = ref.watch(linkedDoctorProvider);
    final caretakersAsync = ref.watch(linkedCaretakersProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Clinical & Care Team'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Clinical Provider Section
            _buildSectionHeader('Primary Physician'),
            const SizedBox(height: 16),
            doctorAsync.when(
              data: (doctor) {
                if (doctor == null) return _buildNoDoctorPrompt(context);
                return _buildDoctorCard(context, doctor);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => _buildErrorCard('Doctor Error: $err'),
            ),

            const SizedBox(height: 40),

            // Caregivers Section
            _buildSectionHeader('Active Caregivers'),
            const SizedBox(height: 16),
            caretakersAsync.when(
              data: (caretakers) {
                if (caretakers.isEmpty) return _buildNoCaretakersPrompt();
                return Column(
                  children: caretakers.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildCaretakerCard(c),
                  )).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => _buildErrorCard('Caretaker Error: $err'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: AppTheme.primaryColor,
        fontWeight: FontWeight.bold,
        fontSize: 12,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildNoDoctorPrompt(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(Icons.medical_services_outlined, size: 48, color: Colors.white24),
          const SizedBox(height: 16),
          const Text('No Doctor Connected', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Link your clinical practice code to share logs with your physician.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () => ConnectDoctorDialog.show(context),
            icon: const Icon(Icons.add_link_rounded),
            label: const Text('Connect Practice'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildNoCaretakersPrompt() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: const Row(
        children: [
          Icon(Icons.people_outline_rounded, color: Colors.white24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'No family or friends are currently monitoring your circle.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorCard(BuildContext context, UserModel doctor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                child: const Icon(Icons.medical_information_outlined, color: AppTheme.primaryColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor.medicalDegree != null ? 'Dr. ${doctor.name}, ${doctor.medicalDegree}' : 'Dr. ${doctor.name}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                    ),
                    const Text('Primary Healthcare Provider', style: TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoRow(Icons.location_on_outlined, 'Practice Location', doctor.clinicAddress ?? 'No clinic info'),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.phone_rounded, 'Main Line', doctor.phone ?? 'N/A'),
          if (doctor.alternativePhone != null && doctor.alternativePhone!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(Icons.contact_phone_outlined, 'Emergency / Alt', doctor.alternativePhone!),
          ],
        ],
      ),
    );
  }

  Widget _buildCaretakerCard(UserModel caretaker) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.person_rounded, color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  caretaker.name ?? 'Unnamed Caregiver',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.phone_rounded, 'Contact', caretaker.phone ?? 'Not set'),
          if (caretaker.alternativePhone != null && caretaker.alternativePhone!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow(Icons.contact_phone_outlined, 'Alt Reach', caretaker.alternativePhone!),
          ],
          if (caretaker.address != null && caretaker.address!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow(Icons.home_rounded, 'Location', caretaker.address!),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: const TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard(String msg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.dangerColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(msg, style: const TextStyle(color: AppTheme.dangerColor, fontSize: 12)),
    );
  }
}
