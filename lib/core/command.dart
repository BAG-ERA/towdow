// Command pattern implementation for MVVM architecture
// Encapsulates user interactions and provides optimistic UI updates

import 'package:flutter/foundation.dart';

/// Base class for all commands in the application
/// Commands encapsulate actions that can be executed, providing a clean separation
/// between UI interactions and business logic
abstract class Command<T> {
  bool _isExecuting = false;
  String? _error;
  final List<VoidCallback> _listeners = [];

  /// Whether the command is currently executing
  bool get isExecuting => _isExecuting;

  /// Error message if the command failed
  String? get error => _error;

  /// Whether the command has an error
  bool get hasError => _error != null;

  /// Add a listener for command state changes
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// Remove a listener
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners of state changes
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  /// Execute the command
  Future<T?> execute() async {
    if (_isExecuting) return null;

    _isExecuting = true;
    _error = null;
    _notifyListeners();

    try {
      final result = await run();
      _isExecuting = false;
      _notifyListeners();
      return result;
    } catch (e) {
      _isExecuting = false;
      _error = e.toString();
      _notifyListeners();
      return null;
    }
  }

  /// Clear any error state
  void clearError() {
    _error = null;
    _notifyListeners();
  }

  /// Dispose resources
  void dispose() {
    _listeners.clear();
  }

  /// Override this method to implement the command logic
  Future<T> run();
}

/// Command that doesn't return a value
abstract class VoidCommand extends Command<void> {}

/// Command with a parameter
abstract class ParameterizedCommand<T, P> extends Command<T> {
  P? _parameter;

  /// Execute the command with a parameter
  Future<T?> executeWith(P parameter) async {
    _parameter = parameter;
    return execute();
  }

  /// Get the current parameter
  P? get parameter => _parameter;

  @override
  Future<T> run() => runWith(_parameter as P);

  /// Override this method to implement the command logic with parameters
  Future<T> runWith(P parameter);
} 
