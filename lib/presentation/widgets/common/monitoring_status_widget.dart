import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers/providers_viewmodels.dart';
import '../../viewmodels/monitoring_status_viewmodel.dart';

class MonitoringStatusWidget extends ConsumerStatefulWidget {
  final bool compact;
  const MonitoringStatusWidget({super.key, this.compact = false});

  @override
  ConsumerState<MonitoringStatusWidget> createState() => _MonitoringStatusWidgetState();
}

class _MonitoringStatusWidgetState extends ConsumerState<MonitoringStatusWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(monitoringStatusViewModelProvider);

    IconData icon;
    Color color;
    String label;

    // Control animation according to state
    if (state == MonitoringUiState.inProgress) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      if (_controller.isAnimating) {
        _controller.stop();
      }
    }

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

    Widget iconWidget = Icon(icon, color: color, size: widget.compact ? 20 : 18);

    if (state == MonitoringUiState.inProgress) {
      iconWidget = RotationTransition(turns: _controller, child: iconWidget);
    }

    if (widget.compact) {
      return Tooltip(
        message: label,
        child: Semantics(
          label: label,
          child: iconWidget,
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
          iconWidget,
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
