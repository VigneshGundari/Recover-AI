import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MedicationCard extends StatefulWidget {
  final String medicationName;
  final String dosage;
  final String? subtitle;
  final String time;
  final bool isTaken;
  final VoidCallback? onMarkAsTaken;
  final String buttonLabel;
  final String successMessage;
  final String recurringSuccessMessage;

  const MedicationCard({
    super.key,
    required this.medicationName,
    required this.dosage,
    this.subtitle,
    required this.time,
    this.isTaken = false,
    this.onMarkAsTaken,
    this.buttonLabel = 'Mark as Taken',
    this.successMessage = 'Taken for today',
    this.recurringSuccessMessage = 'Great work, task completed for the day. See you again tomorrow.',
  });

  @override
  State<MedicationCard> createState() => _MedicationCardState();
}

class _MedicationCardState extends State<MedicationCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.isTaken 
              ? Colors.green.withOpacity(0.2) 
              : AppTheme.primaryColor.withOpacity(0.15),
            AppTheme.primaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.isTaken 
            ? Colors.green.withOpacity(0.4) 
            : AppTheme.primaryColor.withOpacity(0.2), 
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: widget.isTaken 
                          ? Colors.green.withOpacity(0.2) 
                          : AppTheme.primaryColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.isTaken ? Icons.check_circle_rounded : Icons.water_drop_rounded, 
                        color: widget.isTaken ? Colors.green : AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.medicationName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white, // High visibility fix
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.dosage,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle!,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppTheme.primaryColor.withOpacity(0.8),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          widget.time,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: widget.isTaken ? Colors.green : AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.isTaken ? widget.successMessage : 'Upcoming',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: widget.isTaken ? Colors.greenAccent : AppTheme.textSecondary,
                            fontWeight: widget.isTaken ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (widget.isTaken) ...[
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 8),
                  Text(
                    widget.recurringSuccessMessage,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (_isExpanded && !widget.isTaken) ...[
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: widget.onMarkAsTaken,
                      icon: const Icon(Icons.done_all_rounded),
                      label: Text(widget.buttonLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
