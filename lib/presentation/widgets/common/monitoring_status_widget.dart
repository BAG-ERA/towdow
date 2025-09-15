import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers/providers_viewmodels.dart';
import '../../viewmodels/monitoring_status_viewmodel.dart';

class MonitoringStatusWidget extends ConsumerWidget {
  final bool compact;
  const MonitoringStatusWidget({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(monitoringStatusViewModelProvider);

    IconData icon;
    Color color;
    String label;

    switch (state) {
      case MonitoringUiState.inProgress:
        icon = Icons.sync_rounded;
        color = Theme.of(context).colorScheme.primary;
        label = 'Monitoring in progress';
        break;
      case MonitoringUiState.waiting:
        icon = Icons.schedule_rounded;
        color = Theme.of(context).colorScheme.secondary;
        label = 'Monitoring waiting';
        break;
      case MonitoringUiState.offline:
        icon = Icons.wifi_off_rounded;
        color = Theme.of(context).colorScheme.error;
        label = 'Offline: monitoring paused';
        break;
    }

    if (compact) {
      return Tooltip(
        message: label,
        child: Semantics(
          label: label,
          child: Icon(icon, color: color, size: 20),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
