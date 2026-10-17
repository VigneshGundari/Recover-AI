import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recover_ai/features/copilot/data/neo4j_service.dart';
import 'package:recover_ai/features/user/data/user_repository.dart';
import 'package:recover_ai/features/health_tracking/data/local_health_repository.dart';

// Constantly pings the Graph on Dashboard initialization
final interactionCheckerProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userProfile = ref.watch(currentUserProfileProvider).value;
  if (userProfile == null) return [];

  // Re-run whenever the local medication list changes
  ref.watch(todaysMedicationsProvider);

  final service = ref.read(neo4jServiceProvider);
  return await service.checkInteractions(userProfile.uid); 
});

class InteractionCheckerWidget extends ConsumerWidget {
  const InteractionCheckerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interactionsAsync = ref.watch(interactionCheckerProvider);

    return interactionsAsync.when(
      data: (interactions) {
        if (interactions.isEmpty) return const SizedBox.shrink(); // System is Green; No graphical overlaps

        return Column(
          children: interactions.map((interaction) {
            final activeIngredient = interaction['overdoseRisk'];
            final conflictingList = (interaction['conflictingDrugs'] as List).map((e) => e.toString().toUpperCase()).join(' and ');
            
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Graph Intelligence Alert: Chemical Overlap', 
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.redAccent, fontWeight: FontWeight.bold)
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Contradiction Risk: Both $conflictingList physically contain identical Active Ingredients ($activeIngredient). Taking them together triggers an absolute mathematical overdose warning natively via Neo4j.',
                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
      loading: () => const SizedBox.shrink(), // Silent background checking
      error: (e, st) {
        debugPrint('Graph Widget Routing Error: $e');
        return const SizedBox.shrink(); // Fallback smoothly if offline
      },
    );
  }
}
