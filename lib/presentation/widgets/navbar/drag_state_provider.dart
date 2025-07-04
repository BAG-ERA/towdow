// Global drag state provider to track when projects are being dragged
// Allows reorder drop zones to show minimal separators during any drag operation

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DragState {
  final bool isDraggingProject;
  final String? draggedProjectDomain;

  const DragState({
    this.isDraggingProject = false,
    this.draggedProjectDomain,
  });

  DragState copyWith({
    bool? isDraggingProject,
    String? draggedProjectDomain,
  }) {
    return DragState(
      isDraggingProject: isDraggingProject ?? this.isDraggingProject,
      draggedProjectDomain: draggedProjectDomain,
    );
  }
}

class DragStateNotifier extends StateNotifier<DragState> {
  Timer? _dragTimeoutTimer;
  static const Duration _dragTimeout = Duration(seconds: 10);

  DragStateNotifier() : super(const DragState());

  void startDragging(String? projectDomain) {
    // Cancel any existing timeout
    _dragTimeoutTimer?.cancel();
    
    // Set drag state
    state = DragState(
      isDraggingProject: true,
      draggedProjectDomain: projectDomain,
    );
    
    // Start timeout timer as fail-safe
    _dragTimeoutTimer = Timer(_dragTimeout, () {
      // Auto-reset if drag state gets stuck
      reset();
    });
  }

  void stopDragging() {
    // Cancel timeout timer
    _dragTimeoutTimer?.cancel();
    _dragTimeoutTimer = null;
    
    // Reset state
    state = const DragState(
      isDraggingProject: false,
      draggedProjectDomain: null,
    );
  }

  /// Force reset drag state (useful for app lifecycle changes or error recovery)
  void reset() {
    _dragTimeoutTimer?.cancel();
    _dragTimeoutTimer = null;
    
    state = const DragState(
      isDraggingProject: false,
      draggedProjectDomain: null,
    );
  }

  @override
  void dispose() {
    _dragTimeoutTimer?.cancel();
    super.dispose();
  }
}

final dragStateProvider = StateNotifierProvider<DragStateNotifier, DragState>((ref) {
  return DragStateNotifier();
}); 