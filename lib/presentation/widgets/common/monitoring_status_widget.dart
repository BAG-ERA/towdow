import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers/providers_viewmodels.dart';
import '../../viewmodels/monitoring_status_viewmodel.dart';
import 'package:towdow_app/l10n/app_localizations.dart';

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
    final monitoring = ref.watch(monitoringStatusViewModelProvider);

    IconData icon = Icons.schedule_rounded;
    Color color = Theme.of(context).colorScheme.secondary;
    String label = AppLocalizations.of(context)!.monitoringWaiting;

    // Control animation according to state
    if (monitoring.ui == MonitoringUiState.inProgress) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      if (_controller.isAnimating) {
        _controller.stop();
      }
    }

    switch (monitoring.ui) {
      case MonitoringUiState.inProgress:
        icon = Icons.cloud_sync_rounded;
        color = Theme.of(context).colorScheme.primary;
        label = AppLocalizations.of(context)!.monitoringInProgress;
        break;
      case MonitoringUiState.waiting:
        icon = Icons.schedule_rounded;
        color = Theme.of(context).colorScheme.secondary;
        label = AppLocalizations.of(context)!.monitoringWaiting;
        break;
      case MonitoringUiState.offline:
        icon = Icons.wifi_off_rounded;
        color = Theme.of(context).colorScheme.error;
        label = AppLocalizations.of(context)!.monitoringOffline;
        break;
    }

    Widget iconWidget = Icon(icon, color: color, size: widget.compact ? 20 : 18);

    if (monitoring.ui == MonitoringUiState.inProgress) {
      iconWidget = RotationTransition(turns: _controller, child: iconWidget);
    }

    final l10n = AppLocalizations.of(context)!;
    String tooltip;
    if (monitoring.ui == MonitoringUiState.inProgress) {
      tooltip = l10n.monitoringTooltipInProgress;
    } else if (monitoring.ui == MonitoringUiState.offline) {
      tooltip = l10n.monitoringTooltipOffline;
    } else {
      tooltip = l10n.monitoringTooltipWaiting;
    }

    if (widget.compact) {
      return Tooltip(
        message: tooltip,
        child: Semantics(
          label: tooltip,
          child: iconWidget,
        ),
      );
    }

    return Tooltip(
      message: tooltip,
      child: Container(
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
    ));
  }
}
